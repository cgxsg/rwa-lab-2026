# EXERCISES.md — the hands-on list

This file is **what you have to write**. The README tells you what the lab is; this tells you what to do.

Every exercise has one command that answers "am I done?". Red means not done, green means done.
The tests under `test/exercises/` are **deliberately red** — that is not a bug report, that is your task.

---

## Overview

| # | What you will do | Acceptance command | Plank | Where to look if stuck |
|---|---|---|---|---|
| Ex0 | Set up the environment, get the core tests passing | `make test` (7 green) | — | `README.md` "1. Setup" |
| Ex1 | Walk the bridge once on the command line — **warm-up, not graded** | `make subscribe` → `make nav` → `make redeem` | all | `README.md` "2. Quick start", the Ex1 commands below |
| Ex2 | Catch the decimals trap; see that a share is not a dollar | `test_Ex2_*` in `01_AttestationTasks.t.sol` | b | the Ex2 section below |
| Ex3 | Post a false NAV and prove the claim outruns the holdings | a screenshot from `BreakIt.s.sol` | b | the Ex3 commands below |
| Ex4 | Write tests for whitelisting and the issuer's backdoor | `test_Ex4_*` in the same file | d | the Ex4 table below, `STUDENT-QUESTIONS.md` D1/D2 |
| Ex5 | Implement the redemption queue (T+1, FIFO) | all of `02_QueueTasks.t.sol` green | c | `src/exercises/RedemptionQueue.sol` |
| Ex6 | Implement the handler and write the two bridge invariants | all of `03_InvariantTasks.t.sol` green | a/c | `test/exercises/03_InvariantTasks.t.sol` |
| Ex7 | Turn the reporter's key into cash | `make challenge` (**red** until you solve it) | b | `test/challenges/FalseNav.t.sol` |

The deck has three reference pages worth keeping open:
the four planks, the three decimal scales, and the queue state machine.

---

## Ex0 · Environment

```bash
make doctor    # 30 seconds: is this machine ready? anything ✗ comes with its own fix
make test      # acceptance: 7 passed
```

`lib/` (forge-std + OpenZeppelin v5.0.2) **ships inside this repository** — a plain
`git clone` compiles as-is. There is nothing to install, and you do not need `make setup`
unless `lib/` is somehow empty (then `git checkout -- lib` restores it).

Installing Foundry on your own machine is the one step that can fail on a mainland network;
the Setup section of `README.md` covers the `gh-proxy.com` mirror, and Track B (Codespaces)
installs nothing locally.

---

## Ex1 · Walk the bridge once

> **Not graded — a warm-up.** There is nothing to hand in for this one. Walk it once so the
> rest has something to hang on: this is exactly the loop Ex2–Ex6 put under test.

```bash
make anvil                  # terminal A, leave it running
make deploy-anvil           # terminal B
export VAULT=... TBILL=... QUEUE=... CUSTODIAN=... USDC=...
make subscribe AMOUNT=1000000000
make nav                    # the attested NAV, 8 decimals
make holdings               # what the custodian says it holds
make redeem AMOUNT=1000000000000000000
make queue                  # what the queue still owes
```

Watch one number in particular: after `subscribe`, your `balanceOf` is fixed, but when the NAV
moves the **value** of that balance moves with it. A stablecoin would have kept 1:1.

> `make redeem` will revert until you have finished Ex5. That is the queue you have not written yet.

---

## Ex2 · The claim is not a dollar

Open `test/exercises/01_AttestationTasks.t.sol` and write the two `Ex2` tests.

| Function | What you are proving |
|---|---|
| `test_Ex2_ShareIsNotADollar` | after the NAV rises the share **count** is unchanged, but the **value** moved |
| `test_Ex2_DecimalsTrap` | subscribe with `1000e18` instead of `1000e6` and read what happens |

The decimals trap has the same shape as Lab 1 Ex2, but with a third scale:

```
shares   tBILL   18 decimals
NAV      feed     8 decimals
assets   USDC     6 decimals     18 + 8 - 6 = 20
```

> Hint: 1000 USDC is `1000e6`, not `1000e18`. At NAV 1.25, 1000 USDC buys
> `1000e6 * 1e20 / 1.25e8 = 800e18` shares — **fewer** shares, not fewer dollars.

The second test has no expected answer. Run it, read the numbers, then ask yourself:

> This operation **did not revert**, and the vault's bookkeeping **is still consistent**.
> So what exactly went wrong?

---

## Ex3 · Post a false NAV (command line, no tests)

The reporter is the chain's only window onto the asset — plank (b). Here you play a lying reporter.

```bash
# having already run Ex1's subscribe, so there are shares on the books:
export VAULT=... CUSTODIAN=...
forge script script/BreakIt.s.sol:BreakIt --rpc-url $RPC --broadcast
```

`BreakIt.s.sol` attests a NAV of `2e8` ("one share is worth two dollars") and prints, before and
after:

```
NAV per share (8dp)     : 200000000
totalClaimValue (6dp)   : 2000000000     <- what the chain now believes
custodian realHoldings  : 1000000000     <- what is actually there
```

Deliverable: a screenshot of that printout. **That is the bridge failing on plank (b).**
Nothing was hacked; a number was typed in.

`FAKE_NAV=<8-decimal int>` overrides the default if you want a different lie.

---

## Ex4 · The guest list and the backdoor

Same file, `01_AttestationTasks.t.sol`, five tests:

| Function | What you are proving |
|---|---|
| `test_Ex4_NonWhitelisted_CannotSubscribe` | no whitelist, no shares — even if you pay |
| `test_Ex4_NonWhitelisted_CannotReceive` | `_update` checks **both** endpoints, not just the sender |
| `test_Ex4_Unwhitelisted_HolderIsFrozen` | removing one address freezes that individual holder |
| `test_Ex4_IssuerCanBurnAnyBalance` | **and a `MINTER_ROLE` holder can burn anyone's balance** |
| `test_Ex4_Pause_BlocksEverything` | `pause()` freezes transfers, minting and redemption together |

The fourth one is not there to justify the power, it is there to **prove the backdoor exists**.
The third and fourth are the two halves of the compliance tension: a regulated fund really does
need to freeze and seize. That is question D2 in `STUDENT-QUESTIONS.md`.

For `test_Ex4_IssuerCanBurnAnyBalance`: the token's `MINTER_ROLE` starts with the deployer, and
`script/Deploy.s.sol` grants it to the vault and the queue as well. Ask which of these *should*
have it.

---

## Ex5 · The redemption queue

Open `src/exercises/RedemptionQueue.sol` and fill in the four TODOs. This is plank (c): the T+1
settlement a tokenized fund cannot avoid. The tests in `02_QueueTasks.t.sol` are given — they are
your acceptance criteria, and they are red only because these four functions revert.

| TODO | What to do | The hard part |
|---|---|---|
| Ex5.1 `assetsAtNav` | turn shares into USDC at a given NAV | 18 + 8 − 6: divide by 10 to what power? |
| Ex5.2 `enqueue` | escrow the shares, lock the payout at today's NAV, hand out a ticket | record first, or transfer first? |
| Ex5.3 `settle` | pay out FIFO as T+1 cash lands | a ticket is all-or-nothing; a partial fill carries the remainder forward |
| Ex5.4 `claim` | collect a settled ticket | CEI: zero the claim before you transfer |

Acceptance:

```bash
make exercise   # the 02_QueueTasks.t.sol group
```

Three decimals, again — the same table as Ex2. Get it wrong and every payout is off by 10^12.

Two things worth noticing once it is green:

- `test_Ex5_3_Settle_NeedsTheVaultToHoldCash` walks the real T+1 story: the cash was invested, so
  the vault is empty and the settlement cannot draw on it until the SPV wires the proceeds back.
- `settle` has to **burn** the shares it holds, and burning is a balance change — which is why
  the queue itself must be whitelisted. Miss that in `Deploy.s.sol` and the whole loop reverts.

---

## Ex6 · The two bridge invariants

Open `test/exercises/03_InvariantTasks.t.sol`.

Invariant testing flips the usual test around: **let the machine call a pile of operations at
random and in sequence**, then ask "no matter how it thrashes, has this property been broken?"

> **Ex6 depends on Ex5.** The handler calls `enqueue` / `settle` / `claim`, so with the queue
> still stubbed the fuzzer only ever sees reverts and finds nothing.

Five TODOs:

| TODO | What to do |
|---|---|
| Ex6.1 | implement the handler's `enqueue` |
| Ex6.2 | implement the handler's `settle` |
| Ex6.3 | implement the handler's `claim` |
| Ex6.4 | `invariant_EscrowConservation` — the queue holds exactly the shares it still owes |
| Ex6.5 | `invariant_SettlementSolvency` — the queue never owes cash it does not hold |

```bash
make exercise   # the 03_* group
```

When an assertion fails, Foundry prints the **counterexample call sequence** — walk it by hand
and you will see exactly which step, with which arguments, broke the invariant. This is the
closest thing in the lab to a real security audit.

Then answer the question the code cannot: there is a third relation that looks true and is not —

```
vault.reserveBalance() >= queue.pendingAssets()
```

> Why can nobody write that one? When the NAV rises, where does the extra value physically sit —
> in the vault's USDC buffer, or in the T-Bills at the custodian? Write this up as question C1.

---

## Ex7 · Turn the reporter's key into cash

```bash
make challenge     # should be red right now -- that is the puzzle, not a bug
```

The material is in `test/challenges/FalseNav.t.sol`. You are a KYC'd customer who also holds the
reporter's key — a leaked signing key, or a bribed operations desk — and Alice is an honest
holder who did nothing wrong. Your goal: **end with more USDC than you started with, at the
fund's expense.**

The only function you need to change is `test_falseNav()`. The hint is already in there:

> The vault trusts `navPerShare()` for **both** pricing (`subscribe`) and paying out (the queue).
> You can move that number. What is the cheapest path from "I can write the NAV" to "I hold more
> USDC than I started with"?

---

## Deliverables

The homework requirements, grading weights and how to submit are in the "4. Homework" and
"6. Submission" sections of `README.md`.
The discussion questions are in `STUDENT-QUESTIONS.md`.
