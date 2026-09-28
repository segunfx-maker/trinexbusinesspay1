export type DemoTransaction = { id:string; merchant:string; date:string; category:string; status:"Completed"|"Pending"|"Declined"; type:"Incoming"|"Outgoing"; amount:number; account:string; note:string }
export type DemoAccount = { id:string; name:string; kind:"Checking"|"Savings"; currency:string; balance:number; status:"Active"|"Review"; number:string }

export const demoAccounts:DemoAccount[]=[
 {id:"acc-checking",name:"Operations Checking",kind:"Checking",currency:"USD",balance:28437.62,status:"Active",number:"•••• 1842"},
 {id:"acc-savings",name:"Reserve Savings",kind:"Savings",currency:"USD",balance:61508.19,status:"Active",number:"•••• 9076"},
 {id:"acc-euro",name:"European Operations",kind:"Checking",currency:"EUR",balance:12684.43,status:"Review",number:"•••• 4413"},
]

export const demoTransactions:DemoTransaction[]=[
 {id:"DEMO-80419",merchant:"Northstar Design Studio",date:"2026-09-27",category:"Services",status:"Completed",type:"Outgoing",amount:-1287.43,account:"Operations Checking",note:"Illustrative vendor invoice"},
 {id:"DEMO-80418",merchant:"Demo client settlement",date:"2026-09-26",category:"Income",status:"Completed",type:"Incoming",amount:4821.17,account:"Operations Checking",note:"Sandbox receivable"},
 {id:"DEMO-80417",merchant:"Harbor Cloud Systems",date:"2026-09-25",category:"Software",status:"Pending",type:"Outgoing",amount:-318.66,account:"Operations Checking",note:"Illustrative subscription"},
 {id:"DEMO-80416",merchant:"Metro Workspace",date:"2026-09-23",category:"Facilities",status:"Completed",type:"Outgoing",amount:-2460.08,account:"Reserve Savings",note:"Sandbox office expense"},
 {id:"DEMO-80415",merchant:"Test card authorization",date:"2026-09-21",category:"Testing",status:"Declined",type:"Outgoing",amount:-76.21,account:"European Operations",note:"Demo decline scenario"},
 {id:"DEMO-80414",merchant:"Illustrative refund",date:"2026-09-18",category:"Refund",status:"Completed",type:"Incoming",amount:143.52,account:"Operations Checking",note:"Sandbox refund"},
]

export const demoCards=[
 {id:"card-1",name:"Operations card",last4:"4821",holder:"DEMO BUSINESS",frozen:false,limit:3500,spent:1246.72},
 {id:"card-2",name:"Travel card",last4:"1076",holder:"DEMO BUSINESS",frozen:true,limit:2200,spent:417.39},
]

export const demoCrypto=[
 {symbol:"BTC",name:"Bitcoin",units:0.1842,price:68314.27,change:2.4},
 {symbol:"ETH",name:"Ethereum",units:2.736,price:3584.19,change:-1.2},
 {symbol:"USDC",name:"USD Coin",units:1840.53,price:1,change:0},
]

export const demoHoldings=[
 {symbol:"VTI",name:"Total Market ETF",units:42.17,price:287.63,change:1.7},
 {symbol:"BND",name:"Total Bond ETF",units:63.82,price:73.41,change:-0.2},
 {symbol:"VXUS",name:"International ETF",units:38.29,price:65.18,change:0.8},
]

export type AdminRecord={id:string;name:string;type:string;status:string;date:string;owner:string}
export const adminRecords:AdminRecord[]=[
 {id:"DEV-1048",name:"Orchid Works (Demo)",type:"Business",status:"Active",date:"2026-09-27",owner:"Sandbox team"},
 {id:"DEV-1047",name:"Juniper Labs (Demo)",type:"Review",status:"Pending",date:"2026-09-26",owner:"Demo operations"},
 {id:"DEV-1046",name:"Harbor & Pine (Demo)",type:"Business",status:"Flagged",date:"2026-09-24",owner:"Sandbox team"},
 {id:"DEV-1045",name:"Atlas Field Co. (Demo)",type:"Individual",status:"Active",date:"2026-09-22",owner:"Demo support"},
 {id:"DEV-1044",name:"Copperline Goods (Demo)",type:"Business",status:"Closed",date:"2026-09-20",owner:"Demo operations"},
 {id:"DEV-1043",name:"Cedar Peak (Demo)",type:"Review",status:"Pending",date:"2026-09-18",owner:"Sandbox team"},
 {id:"DEV-1042",name:"Meridian Demo Ltd.",type:"Business",status:"Active",date:"2026-09-15",owner:"Demo support"},
]
