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

- Revenue is the platform's fee, not the transaction value. On a £1,000 payment at 20%, revenue is £200. When a refund, chargeback or fraud reverses that payment, the platform gives back its £200 and revenue for the sale nets to zero. The alternative is taking the whole £1,000 off revenue, but that makes total revenue negative (−£0.52m), which doesn't make sense. If the platform really does swallow the full loss, I'd report that as a separate cost.
- Refunds give back the fee that was actually charged. If the original payment was discounted to 17.5%, the refund takes back 17.5%, not the default 20%. Refunds link to their payment so this is easy to look up. It makes no difference here as nobody gets a discount, but it's the right logic.
- Spend towards a threshold is payments made during the contract. Refunds and chargebacks don't reduce it. Net spend is common in contracts, but it can be confusing: a client hits their threshold, gets the discount, then a late refund takes them back under it. Other ways round that are only assessing spend on closed months, or netting refunds but never taking a discount away once it's been given. That last one is close to what I've done, except refunds don't count at all here, so clients would cross a bit sooner. Nobody gets near their threshold either way.
- The discount starts the day after the threshold is crossed, so everything on the crossing day is charged at 20%. We only have dates, not times, so there's no reliable order within a day. I looked at using transaction ID as a tiebreak, but the IDs aren't in date order (T000001 is in May, T000002 is in June), so it would have been arbitrary. Other options are discounting everything on the crossing day, splitting the crossing payment across both rates, or starting from the next month if spend is assessed monthly. None of this changes the output here as nobody crosses.
- Chargebacks count in the month they're resolved, and pending ones are left out. A chargeback raised in January and resolved in February counts in February. The alternative is January, but that would change January's numbers after they'd been reported. Refunds already work this way, landing in the month they happen, so nothing changes a month once it's closed. The original dates are kept for anyone who wants to look at it the other way.
- Contracts only apply between their start and end dates. Payments outside those dates don't count towards the threshold and are charged at 20%. This matters for C003 and C004, whose contracts start in February and March, and C002, whose contract ends in June.
- Clients with no contract pay the default 20% and have no threshold. Six of the ten clients.
- Missing exchange rates use the last rate available. Rates stop on 30 June but transactions run to 6 July. It only affects four refunds, all in GBP, so there's no value impact. Dropping them or leaving them blank would have lost about £190k of refunds.
- Resolved means the chargeback stood and the money went back to the customer. The data doesn't say who won.
- Every amount in the source data is positive, including refunds, chargebacks and fraud. The sign is applied by transaction type, so payments add and everything else takes away.
- The brief asks for total GMV but doesn't say gross or net, so the mart has both. Gross is payments only. Net takes off refunds, resolved chargebacks and fraud. Because reversals can land in a later month than the sale, a month's net GMV and revenue can be negative.

## What I found

- Nobody hits their threshold, so no discounts are applied. C001 gets closest at 76%.
- Revenue is £2.32m on £19.13m of payments.
- C005 and C008 have no contract but put more through than C001, which does. One for account management.
- 16 of the 17 pending chargebacks are over 30 days old, but resolved ones all close within 15. Something's not right there.
- Resolution dates come in as dd/mm/yyyy. Everything else is ISO. Worth fixing at source.

## Tests

Standard key and relationship tests, a few business rule checks, reconciliation from staging through to the mart, and unit tests for the discount and chargeback logic, since the real data never triggers a discount.

There are three warnings: clients without a contract, old pending chargebacks, and fallback exchange rates. They're here to show what I checked. In practice I wouldn't leave warnings firing on every run, as people stop reading them. The contract one would just be documentation and the other two would go to whoever owns the data.

SQLite doesn't really do types, so derived columns are cast explicitly. Otherwise the unit tests read dates as numbers.

## Next steps

- Lock closed months so late data can't restate them.
- Freshness and sanity checks on the rates feed.
- Confirm the spend and discount rules with finance.

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
