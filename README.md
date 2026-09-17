# Global Transactions Assessment

Original brief is at the bottom.

## Running it

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install 'dbt-sqlite>=1.10,<1.11'
export DBT_PROFILES_DIR=.
dbt build
```

## How I approached it

1. Got it running. The setup guide says the database is pre-built, but it was empty, so I loaded the seeds with `dbt seed`. The starter model then wouldn't compile because of a trailing comma, which I fixed before touching anything else.
2. Built the staging models. One per seed, with light cleaning and tests. The main fix was resolution dates, which come in as dd/mm/yyyy while everything else is ISO.
3. Worked through the business logic in three intermediate models: currency conversion, contract discounts, then revenue. The brief doesn't say how a lot of this should work, so I had to make some calls that would normally be agreed with stakeholders. They're listed under assumptions below.
4. Built a client x month spine and the final mart on top of it, with tests that reconcile it back to the transactions.

## Models

Each intermediate model does one job and feeds the next. The three transaction models stay at one row per transaction, and only the mart rolls up to client and month.

```
stg_transactions ─────────────┐
stg_currency_rates ───────────┤
                              ▼
            int_transactions_converted_to_gbp        adds amount_gbp
                              │
stg_client_contracts ─────────┤
                              ▼
            int_transactions_with_discount_status    adds contract spend and the fee margin charged
                              │
stg_transaction_resolutions ──┤
                              ▼
            int_transactions_revenue_recognised      adds signed amounts, revenue and the month it counts in
                              │
                              ├──────────► int_client_months    every client for every month
                              ▼                       │
            fct_client_monthly_revenue ◄──────────────┘
            one row per client per month
```

The order matters. Thresholds are in pounds, so spend can't be worked out until amounts are converted. Revenue depends on which margin was charged, so it has to come after the discount logic.

`int_client_months` is a date spine: every client crossed with every month from January to July. Without it, a month where a client did nothing would just be missing from the output. With it, that month shows zero revenue and spend to date carries forward, so threshold tracking has no gaps. SQLite has no date spine function, so it's built with a recursive CTE.

## Assumptions

The brief leaves a lot open. Normally I'd check these with stakeholders, but for the exercise I've picked an option and noted the alternatives.

- Revenue is the platform's fee, not the transaction value. On a £1,000 payment at 20%, revenue is £200. When that payment is refunded, the platform gives back its £200 and revenue for the sale nets to zero. The alternative is taking the whole £1,000 off revenue. Doing that for chargebacks and fraud alone turns total revenue negative (−£0.52m), and for all three reversal types it's −£3.70m, so I don't think that's the intent. If the platform really does swallow the full loss, I'd report it as a cost rather than negative revenue.
- Refunds give back the fee that was actually charged. If the original payment was discounted to 17.5%, the refund takes back 17.5%, not the default 20%. Refunds link to their payment so this is easy to look up.
- Chargebacks and fraud reverse at the default 20%, because they carry no link to the payment they reverse. Using whatever rate happens to apply on their own date would reverse a 20% sale at 17.5% for a client that had since crossed its threshold, leaving phantom revenue behind.
- Refunds convert to GBP at the rate used for the payment they reverse, not the rate on the day of the refund. Otherwise a fully refunded USD sale leaves a small residue in GMV and revenue. Across this data that was about £269 of revenue.
- Spend towards a threshold is payments made during the contract. Refunds and chargebacks don't reduce it. Net spend is common in contracts, but it can be confusing: a client hits their threshold, gets the discount, then a late refund takes them back under it. Other ways round that are only assessing spend on closed months, or netting refunds but never taking a discount away once it's been given. That last one is close to what I've done, except refunds don't count at all here, so clients would cross a bit sooner. Nobody gets near their threshold either way.
- The discount starts the day after the threshold is crossed, so everything on the crossing day is charged at 20%. We only have dates, not times, so there's no reliable order within a day. I looked at using transaction ID as a tiebreak, but the IDs aren't in date order (T000001 is in May, T000002 is in June), so it would have been arbitrary. Other options are discounting everything on the crossing day, splitting the crossing payment across both rates, or starting from the next month if spend is assessed monthly. None of this changes the output here as nobody crosses.
- Chargebacks count in the month they're resolved, and pending ones are left out. A chargeback raised in January and resolved in February counts in February. The alternative is January, but that would change January's numbers after they'd been reported. Refunds already work this way, landing in the month they happen, so nothing changes a month once it's closed. The original dates are kept for anyone who wants to look at it the other way.
- Contracts only apply between their start and end dates. Payments outside those dates don't count towards the threshold and are charged at 20%. C003 and C004 were both trading before their contracts started, so £299,539 and £722,750 of their payments don't count towards their thresholds.
- Clients with no contract pay the default 20% and have no threshold. Six of the ten clients.
- Where a transaction has no rate for its own date, it uses the last rate available. Rates stop on 30 June but transactions run to 6 July. Nothing needs that fallback now, as the four July transactions are refunds and take their payment's rate, but it's there so a gap in the rates feed can't silently drop a transaction or leave it with no GBP amount.
- Resolved means the chargeback stood and the money went back to the customer. The data doesn't say who won.
- Every amount in the source data is positive, including refunds, chargebacks and fraud. The sign is applied by transaction type, so payments add and everything else takes away.
- The brief asks for total GMV but doesn't say gross or net, so the mart has both. Gross is payments only. Net takes off refunds, resolved chargebacks and fraud. Because reversals can land in a later month than the sale, a month's net GMV and revenue can be negative.
- Money is kept at full precision through the models and rounded to the penny in the mart, so rounding doesn't build up through the joins.

## What I found

- Nobody hits their threshold, so no discounts are applied. C001 gets closest at 76%.
- Revenue is £2.32m on £19.13m of payments.
- C005, C008 and C009 have no contract but each put more through than C001, which has one. One for account management.
- 16 of the 17 pending chargebacks are over 30 days old, but resolved ones all close within 15. Something's not right there.
- Six payments have been refunded more than once, and in each case the refunds add up to more than the payment was worth. That's £175k of refund volume and £35k of fee reversal that shouldn't be there. I've flagged them with a test rather than dropping them, as it could be a genuine double refund. Worth a conversation before anyone nets them out.
- Two clients were trading before their contracts started: C003 from January against a February contract, C004 from January against a March one. Worth checking whether the contracts were meant to be backdated.
- July is a partial month. The data stops on the 6th, so it has four refunds and four chargeback resolutions and no payments at all. Every client shows zero GMV and some show negative revenue, which is correct but looks alarming. In a real build I'd carry an as-of date and mark incomplete months.
- Resolution dates come in as dd/mm/yyyy. Everything else is ISO. Worth fixing at source.

## Gotchas

Everything that would quietly give a wrong answer, and what I did about it.

| Gotcha | How it's handled |
|---|---|
| Starter model had a trailing comma and wouldn't compile | Fixed first, as its own commit |
| "Pre-built" database was empty | `dbt seed` loads it; `dbt build` does everything from scratch |
| Resolution dates are dd/mm/yyyy, everything else ISO | Parsed once in staging. `date()` returns null on these rather than erroring, so a not-null test and a round-trip test catch a silent parse failure |
| SQLite normalises impossible dates, so 31/04 becomes 1 May | Round-trip test compares the parsed date back to the source string |
| Exchange rates stop on 30 June, transactions run to 6 July | Each row takes the latest rate on or before its date, with a test that the right rate was picked and a warning when a fallback is used |
| A refunded USD sale didn't net to zero | Refunds convert at the rate used for the payment they reverse |
| Six payments are refunded more than once, for more than they were worth | Flagged with a warning test, not silently dropped. £175k of refunds, £35k of fee reversal |
| Chargebacks and fraud have no link to the payment they reverse | They reverse at the default margin rather than guessing a rate |
| Pending chargebacks: 16 of 17 are over 30 days old | Excluded from revenue until resolved, and a warning test flags the backlog |
| Six of ten clients have no contract | Left-joined so they're kept, always on the default rate, with tests that they're never discounted and never dropped |
| Two clients traded before their contracts started | Contract dates are respected, so that spend doesn't count towards their thresholds |
| Contracts starting on the 31st would roll into the wrong month | End dates cap the day at the end of the target month, with a unit test |
| Transaction IDs aren't in date order | No business logic depends on their order; the discount starts the day after a threshold is crossed. They're only a tiebreak inside one test |
| Every amount arrives positive, including reversals | Signs applied by transaction type, with a test on every row |
| SQLite barely enforces types, so a date can become a number | Every derived column is cast explicitly |
| Rounding could build up through the joins | Full precision through the models, rounded at the mart, with reconciliation tests that compare exactly |

## Tests

Standard key and relationship tests, a few business rule checks, reconciliation from staging through to the mart, and unit tests for the discount and chargeback logic, since the real data never triggers a discount.

Three warnings fire on every run: clients without a contract, chargebacks pending over 30 days, and payments that have been refunded more than once. A fourth, for fallback exchange rates, is quiet at the moment. They're here to show what I checked. In practice I wouldn't leave warnings firing every run, as people stop reading them. The contract one would just be documentation and the rest would go to whoever owns the data.

SQLite doesn't really do types, so derived columns are cast explicitly. Otherwise the unit tests read dates as numbers.

A GitHub Actions workflow runs `dbt build` on every pull request and push to main.

## Next steps

- Confirm the assumptions above with finance and whoever owns the client contracts. Some of them would change the numbers. If the platform keeps its fee on refunds, for example, revenue goes up by about £0.8m.
- Take the data issues to their owners: the stuck pending chargebacks, the date format on resolutions, and the rates feed stopping before the transactions do.
- Move it onto a proper warehouse. SQLite is fine for this exercise but most of what's below needs a real one.
- Add Elementary for anomaly detection. At the moment the tests only catch rules I thought of. Elementary would flag things like a sudden drop in daily volume, a jump in refunds or a late rates feed, and send alerts to the right people instead of leaving warnings in the logs.
- Define revenue and GMV as metrics in the dbt semantic layer. Everyone would get the same numbers whatever tool they use, and it opens the door to asking questions in plain English through an AI tool, without having to know which model or filter to use.
- Snapshot each month's figures when a month closes. Recognising chargebacks on their resolution date only protects closed months if the resolution arrives promptly. A resolution loaded late but dated into a closed month would still restate it, and with 16 chargebacks pending for over 30 days that's a real risk here. Keying recognition off when the resolution was loaded, or holding a snapshot, would fix it properly.
- Build on the CI. It only runs `dbt build` at the moment. I'd add AI code review on pull requests, only build what's changed and what depends on it, add more tests as the rules get confirmed, and hook it into proper observability so failures and anomalies reach the right people.

---

## Original brief

### Overview

This dbt project is designed to process and analyze transaction data for a global marketplace platform. The project handles various transaction types, currency conversions, and revenue recognition rules.

### Project Structure

- `seeds/`: Contains raw CSV data files
  - `transactions.csv`: All platform transactions
  - `client_contracts.csv`: Client discount agreements
  - `currency_rates.csv`: Daily currency exchange rates
  - `transaction_resolutions.csv`: Chargeback resolution statuses

- `models/`: Contains all dbt models
  - `staging/`: Initial data cleaning and standardisation
  - `intermediate/`: Complex calculations and business logic
  - `marts/`: Final layer for reporting

### Target configuration

This project writes to a SQLite database in the target directory. You will need to install the dbt-sqlite adapter to run it.

```yaml
global_transactions:
  target: dev
  outputs:
    dev:
      type: sqlite
      threads: 1
      database: 'database'
      schema: 'main'
      schema_directory: 'target'
      schemas_and_paths:
        main: 'target/global_transactions.db'
```

### Key Requirements

1. Handle multiple transaction types (payments, refunds, fraud, chargebacks)
2. Apply correct platform fee margins based on client contracts
3. Convert all amounts to GBP using daily exchange rates
4. Calculate monthly revenue recognising only resolved chargebacks

### Expected Output

The final mart model should provide monthly revenue recognition with:
- Revenue by client and month
- Total GMV in GBP
- Spend threshold tracking
- Discount application status
