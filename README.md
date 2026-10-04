# Lab 2 — How to Tokenize an RWA (Tokenized T-Bills)

In Lab 1 the collateral was **itself a token**. That is why the whole thing could prove itself:
`totalCollateral() == totalSupply()` was a statement the chain could check on its own, and nothing
outside the code had to be trusted.

This lab removes that assumption. The asset is now a **short-dated US Treasury bill**, sitting at a
custodian. What is on-chain is not the asset — it is a **claim on the asset**. The subject of this
lab is the machinery that connects the two:

> **The bridge.** Custody, attestation, physical redemption, and permissioning — the four things
> that have to exist before an off-chain asset can become an on-chain token, and the four places
> where such a token breaks.

Every exercise below is built around a plank of the bridge. If you find yourself only reading NAV
numbers and yields, you have drifted back into Lab 1.

---

## 1. Setup

Pick the track that matches your machine. **Everything after this section is identical for everyone.**

| You are on | Track |
|---|---|
| macOS / Linux | **A** — install Foundry locally |
| Windows | **B** — Codespaces, nothing installed on your machine |

> `lib/` (`forge-std`, `openzeppelin-contracts`) **ships inside this repository**.
> Neither track needs `git clone --recursive`, and neither needs `make setup` —
> a plain clone compiles as-is.

### Track A — macOS / Linux

**Step 1. Install Foundry**

First check whether you already have it:

```bash
forge --version
```

If that prints a version, skip to Step 2. Otherwise install it with the script in this repo (**do not use `foundryup`**):

```bash
bash scripts/install-foundry-cn.sh
```

The script detects your platform (macOS ARM / Intel, Linux x86_64 / arm64), tries GitHub directly, and falls back to the `gh-proxy.com` mirror. Add the line it prints to `~/.zshrc` or `~/.bashrc`, then reopen your terminal:

```bash
export PATH="$PATH:$HOME/.foundry/bin"
```

> ⚠️ **Why not `foundryup`**: its release download goes through GitHub's CDN, which times out
> reliably from mainland China. The mirror in `scripts/install-foundry-cn.sh` does not.

**Step 2. Get the code**

```bash
git clone https://github.com/hgwoops/rwa-lab-2026 && cd rwa-lab-2026
```

Then go to **Verify** below.

### Track B — Windows (Codespaces)

Foundry has **no native Windows binary**, so the straightforward path is to run the lab on
GitHub's servers from your browser. Nothing is installed locally, which also makes it the only
option on locked-down corporate machines.

1. Open <https://github.com/hgwoops/rwa-lab-2026>
2. Green **`Code`** button → **`Codespaces`** tab → **`Create codespace on main`**
3. **The first launch takes 2–5 minutes**: it builds the environment from `.devcontainer/`,
   then automatically runs `make doctor` — you should see a row of `✓` in the terminal
4. In the terminal at the bottom, run:

```bash
make test
```

`7 passed; 0 failed` means you are set.

The free tier is 120 core-hours/month (≈ 60 real hours on a 2-core machine), far more than
this lab needs. **Stop it when you are done** at <https://github.com/codespaces> — a running
Codespace keeps burning quota.

### Verify (both tracks)

```bash
make doctor
```

In about 30 seconds this tells you whether the machine is ready for class: it checks the
toolchain, the dependencies, and actually runs the core tests. Anything marked `✗` comes with
the exact command to fix it.

All green means you can start. **If you cannot fix it, paste the entire `make doctor` output to the TA.**

---

## 2. Quick start

```bash
make doctor        # environment check — all green before you go on
make test          # the checkpoint: core tests, should be all green (7 passed)
make exercise      # the hands-on tasks; red right now — the red ones ARE your task list
make anvil         # terminal A: start a local chain
make deploy-anvil  # terminal B: deploy to it
```

Deployment prints eight addresses — write them down (referred to below as `$USDC`,
`$COMPLIANCE`, `$FEED`, `$TBILL`, `$CUSTODIAN`, `$VAULT`, `$QUEUE`). For the full set of
subscription, attestation and redemption commands, see Ex1 and Ex3 in `EXERCISES.md`.

**Your task list lives in `EXERCISES.md`** — every exercise's goal, acceptance command, and
where to look when you get stuck.

---

## 3. What the contracts do

The bridge has four planks. Each one is a contract or a role in this repo.

| File | Role | Plank |
|---|---|---|
| `src/MockUSDC.sol` | **Cash.** 6 decimals, with a test faucet. The thing that flows across the bridge | — |
| `src/ComplianceRegistry.sol` | **The guest list.** `setWhitelisted()` / `isWhitelisted()`, gated by `COMPLIANCE_ROLE` | (d) admission |
| `src/TBillToken.sol` | **The claim.** ERC-20, **18 decimals**, mint/burn gated, and every balance change must pass both endpoints' whitelist | (d) admission |
| `src/TBillVault.sol` | **The on-ramp and the books.** `subscribe()` prices shares at the attested NAV; `attest()` is the reporter's only way to move it | (b) attestation |
| `src/exercises/MockTBillCustodian.sol` | **The custodian / SPV.** Answers exactly one question: `realHoldings()` — how much is actually there? | (a) custody |
| `src/exercises/MockPriceFeed.sol` | **The NAV oracle.** 8 decimals; `1.00e8` is par | (b) attestation |
| `src/exercises/RedemptionQueue.sol` | **T+1.** Shares in, a queue ticket out, cash later — **your TODOs, Ex5** | (c) redemption |

### The three decimal scales — the sequel to Lab 1 Ex5

```
shares   tBILL   18 decimals
NAV      feed     8 decimals
assets   USDC     6 decimals     18 + 8 - 6 = 20  ->  DECIMALS_SCALE = 1e20
```

### The two invariants you will defend (Ex6)

```
escrow conservation   tBill.balanceOf(queue) == queue.pendingShares()
settlement solvency   usdc.balanceOf(queue) >= queue.totalClaimable()
```

The first says the queue never loses a share and never invents one. The second says it never owes
settled cash it does not hold. Neither is something the chain can verify against the off-chain
asset — that is the point.

There is a third relation that looks equally true and is not:

```
vault.reserveBalance() >= queue.pendingAssets()     // NOT an invariant
```

When the NAV rises, the extra value is not in the vault's USDC buffer — it is in the T-Bills at
the custodian. So the vault can owe more than it holds cash for, and no code change fixes that:
the cash has to be wired back first. Question C1 in `STUDENT-QUESTIONS.md` is about exactly this.

`script/Deploy.s.sol` wires the whole system together, and the wiring at the bottom **is** part of
the lesson: the vault needs `MINTER_ROLE`; the queue needs `MINTER_ROLE` **and** must be
whitelisted (burning its escrowed shares is a balance change); the vault must be told where the
queue is; the custodian must recognize the vault. Skip any one and the loop reverts.

---

## 4. Homework

### Tier 1 (required) — Ex0–Ex6 in `EXERCISES.md`

1. **Ex0 Environment**: `make doctor` all green → `make test` all green (7 passed)
2. **Ex1 The loop** (warm-up, **not graded**): subscribe once from the command line, watch the
   claim value move when the NAV is attested, then enqueue one redemption
3. **Ex2 Decimals and the claim**: fill in the `Ex2` tests — a share is not a dollar
4. **Ex3 Break the NAV by hand**: use `cast` to attest a fake NAV and screenshot the claim value
   far exceeding `realHoldings()` (plank b)
5. **Ex4 Admission and permission**: write the compliance tests — whitelist blocks, force-transfer
   backdoor (plank d)
6. **Ex5 The redemption queue**: implement the four TODOs in `src/exercises/RedemptionQueue.sol`
7. **Ex6 Invariant testing**: implement the handler and write the two `invariant_*` tests
8. Answer the discussion questions in `STUDENT-QUESTIONS.md`

> Tier 1 does **not** require deploying to a testnet — a local Anvil is enough.
> The acceptance command for every exercise is `make exercise`; when you are done it should be all green.

### Tier 2 (bonus)

Deploy to the Sepolia testnet and verify the source on Etherscan; submit the contract links.
See `README.md` §6 in Lab 1 for the exact commands — the flow is identical.

### Tier 3 (challenge, optional)

**Ex7 · Post a false NAV**: `make challenge` (`test/challenges/FalseNav.t.sol`).
The reporter's number is the chain's only window onto the asset. Show what happens when it lies,
and name the mechanism that would have caught it.

---

## 5. Common problems

**`Ownable` / role errors**
OpenZeppelin v5 has breaking changes, so v4 tutorials from the web will fail. This repo pins
`v5.0.2` — do not upgrade it.

**`subscribe` reverts with `NotWhitelisted`**
The token is permissioned. Whitelist the recipient first — and remember the **queue** must be
whitelisted too, because burning its escrowed shares counts as a balance change.

**`invest` reverts with `AccessControlUnauthorizedAccount`**
The custodian does not recognize the vault. `script/Deploy.s.sol` grants
`custodian.CUSTODIAN_ROLE()` to the vault — if you wired things by hand, you skipped it.

**Amounts are off by an order of magnitude**
`1000e6 = 1_000_000_000` in smallest units (USDC). Shares are 18 decimals and the NAV is 8 — the
conversion is `shares * nav / 1e20`. Do not compute 18-decimal to 18-decimal.

**Addresses change after restarting Anvil**
Anvil starts from a clean state every time, so you must redeploy. To keep state, use
`anvil --load-state demo-state.json`.

**`make exercise` is all red**
That is expected — the tests under `test/exercises/` are **deliberately red**; they are your task
list. `make test` is the "everything is fine" checkpoint. Once you finish, `make exercise` goes green.

**`make exercise` hangs, or an invariant failure looks strange**
Foundry stores invariant counterexamples in `cache/invariant/` and replays them on the next run.
To search for a fresh counterexample, `rm -rf cache/invariant` first.

---

## 6. Submission

Submission follows Lab 1: **one zip of the project** on Moodle, built from the project root.

```bash
rm -f .env        # a private key anywhere in the zip scores zero
zip -r submission.zip . -x '.git/*' 'out/*' 'cache/*' 'broadcast/*' '.env' '.DS_Store'
```

**Keep `lib/` inside it** — those vendored dependencies are what let the grader run `make test`
offline. Drop them and the grader has to fetch from GitHub.

What the zip must contain:

1. The code, with `make exercise` all green (the grader re-runs `make test` themselves)
2. Ex3's screenshot — the attested claim value far greater than `realHoldings()`
3. Your answers to the discussion questions in `STUDENT-QUESTIONS.md`
4. An architecture diagram in your `README.md` — a photo of a hand drawing is fine, but it must
   show the **four planks** and where cash and shares cross the bridge

---

## 7. Questions left to you

These have no standard answers. They are the real point of this lab:

1. The vault holds `MINTER_ROLE`, so it can mint shares to anyone. Who should hold that key when
   the shares represent a real fund?
2. `attest()` is the only way the chain learns the NAV. What stops the reporter from lying? Name
   at least two mechanisms — one technical, one legal or operational.
3. The queue locks the payout at the NAV of `enqueue` time, not `settle` time. Who bears the risk
   of a NAV move in between, the redeemer or the remaining holders?
4. Whitelisting every holder means the issuer has a backdoor. Between "fully permissionless" and
   "fully gated", where would a regulated tokenized fund have to sit, and why?

Question 1 is the thread back to Lab 1's `MINTER_ROLE`; question 4 is the one with no clean answer.
