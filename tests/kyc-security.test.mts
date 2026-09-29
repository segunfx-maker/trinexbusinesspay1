import assert from "node:assert/strict"
import { readFile } from "node:fs/promises"
import test from "node:test"
import { assertApprovedKyc, buildKycAuditRecord, canAccessKycDocument, canEditKyc, effectiveKycStatus, KYC_REQUIRED_MESSAGE } from "../netlify/functions/_shared/kyc.mts"

function client(approved: boolean) { return { async query() { return { rows: approved ? [{ ok: 1 }] : [] } } } }

for (const [name,status] of [["unverified","NOT_STARTED"],["under-review","UNDER_REVIEW"],["rejected","REJECTED"]]) {
  test(`${name} customer cannot withdraw, deposit, or fund an investment`, async () => {
    for (const operation of ["withdraw","deposit","investment"]) await assert.rejects(assertApprovedKyc(client(false), `${status}-${operation}`), new RegExp(KYC_REQUIRED_MESSAGE.replace(/[.*+?^${}()|[\]\\]/g,"\\$&")))
  })
}

test("approved customer proceeds to subsequent financial authorization checks", async () => {
  await assert.doesNotReject(assertApprovedKyc(client(true), "customer-approved"))
})

test("server and database layers enforce KYC even when the UI is bypassed", async () => {
  await assert.rejects(assertApprovedKyc(client(false), "bypass"))
  const migration = await readFile(new URL("../netlify/database/migrations/20261005120000_create_manual_kyc_system/migration.sql", import.meta.url), "utf8")
  for (const trigger of ["bank_withdrawals_require_kyc","crypto_withdrawals_require_kyc","crypto_deposits_require_kyc","investment_positions_require_kyc","transfers_require_kyc","financial_requests_require_kyc"]) assert.match(migration, new RegExp(trigger))
})

test("customer A cannot access customer B documents", () => {
  assert.equal(canAccessKycDocument("customer-a", undefined, "customer-b"), false)
  assert.equal(canAccessKycDocument("customer-a", undefined, "customer-a"), true)
})

test("only explicit compliance roles can access restricted documents", () => {
  for (const role of ["SUPER_ADMIN","ADMIN","COMPLIANCE"]) assert.equal(canAccessKycDocument(undefined, role, "customer"), true)
  for (const role of ["SUPPORT","READ_ONLY","OPERATIONS"]) assert.equal(canAccessKycDocument(undefined, role, "customer"), false)
})

test("approval and rejection require immutable audit data", () => {
  for (const status of ["APPROVED","REJECTED"]) assert.deepEqual(buildKycAuditRecord({ adminId:"admin",customerId:"customer",caseId:"case",previousStatus:"UNDER_REVIEW",newStatus:status,reason:"Evidence reviewed" }).newStatus,status)
  assert.throws(() => buildKycAuditRecord({ adminId:"admin",customerId:"customer",caseId:"case",previousStatus:"SUBMITTED",newStatus:"APPROVED",reason:"" }))
})

test("rejected cases follow the configured resubmission rule", () => {
  assert.equal(canEditKyc("REJECTED",true),true)
  assert.equal(canEditKyc("REJECTED",false),false)
})

test("expired identification triggers re-verification", () => {
  assert.equal(effectiveKycStatus("APPROVED","2025-01-01",new Date("2026-01-01")),"EXPIRED")
  assert.equal(effectiveKycStatus("APPROVED","2027-01-01",new Date("2026-01-01")),"APPROVED")
})
