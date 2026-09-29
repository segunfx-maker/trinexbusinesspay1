import test from "node:test"
import assert from "node:assert/strict"
import { readFile } from "node:fs/promises"

const signIn = await readFile(new URL("../src/app/(auth)/sign-in/page.tsx", import.meta.url), "utf8")
const signUp = await readFile(new URL("../src/app/(auth)/sign-up/page.tsx", import.meta.url), "utf8")
const callback = await readFile(new URL("../src/components/auth-callback-handler.tsx", import.meta.url), "utf8")

test("email and password login remains available",()=>{assert.match(signIn,/login\(/);assert.match(signIn,/type="email"/);assert.match(signIn,/name="password"/);assert.match(signIn,/Sign in/i)})
test("email and password registration remains available",()=>{assert.match(signUp,/signup\(/);assert.match(signUp,/type="email"/);assert.match(signUp,/name="password"/);assert.match(signUp,/Create account/i)})
test("password recovery remains available",()=>{assert.match(signIn,/requestPasswordRecovery/);assert.match(signIn,/Forgot password/i);assert.match(callback,/recovery_token/);assert.match(callback,/confirmation_token/)})
test("Google and Apple authentication are unavailable",()=>{for(const source of [signIn,signUp]){assert.doesNotMatch(source,/oauthLogin/);assert.doesNotMatch(source,/google/i);assert.doesNotMatch(source,/apple/i)}assert.doesNotMatch(callback,/access_token/)})
