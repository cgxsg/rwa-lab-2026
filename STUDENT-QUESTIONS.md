# STUDENT-QUESTIONS.md — Discussion questions (goes inside your submission zip)

Answer directly under each question. 150–300 words each — **reasoning over length**.

The sections follow the four planks of the bridge. There are no standard answers; these are the
real point of the lab.

---

## A. Custody — where the asset actually is (plank a)

**A1.** In Lab 1, `totalCollateral()` read the vault's own ERC-20 balance, and the chain could
prove the invariant. Here, `MockTBillCustodian.realHoldings()` is just a number that a permissioned
address can move. Write the equivalent of `totalCollateral() == totalSupply()` for *this* system.
What does it actually assert, and what does it no longer prove?

> Your answer:
The equivalent invariant is that the reported value of the custodian's T-Bill holdings should cover the total value of outstanding token claims. If `realHoldings()` represents the reported asset value and `totalSupply() × NAV` represents the corresponding liability, the condition is `realHoldings() >= totalSupply() × NAV`, after decimal scaling. Equality is expected when all assets and liabilities are recorded and the fund holds no extra reserve.
In this lab, `realHoldings()` is only a number that a permissioned address can change. The invariant checks whether the reported asset value covers the token liabilities; it does not prove that the securities actually exist. An authorized reporter could increase the reported holdings without buying any T-Bills, and the contract would still pass the check while the fund was economically undercollateralized.
In Lab 1, the chain could read the vault's ERC-20 balance and verify the invariant from on-chain state. Here, it cannot inspect an off-chain securities account. The check can still reveal an accounting imbalance, but it cannot establish legal ownership, custody reliability, or the truth of an external report. Independent statements, custody records, and audits are therefore necessary. Without these external checks, a passing invariant could describe a fund that holds nothing at all.

<br><br><br>

**A2.** The T-Bills are held by an SPV, a legal entity set up so the fund's assets are bankruptcy-
remote from the issuer. Explain in your own words why a *legal* structure is part of a *technical*
design. If the SPV's custodian goes bankrupt, what does the on-chain token entitle its holder to?

> Your answer:
The SPV belongs to technical design because on-chain transfer does not create ownership of the T-Bills or avoid them from the issuer's creditors. The SPV is used to separate the fund's assets from the issuer's other estate, so the issuer's insolvency is less likely to make those assets into unrelated debts.
The contract can only manage things on the blockchain, it cannot decide how a court will treat the securities in insolvency. The results depends on the SPV structure, ownership records, custody arrangements, and corresponding laws. If the SPV's custodian goes bankrupt, holders do not suddenly get on-chain access to the T-Bills. Their rights depend on whether the securities were segregated, whether the SPV still holds legal title, and whether the custodian's records prove ownership. They may have a  contractual claim, but enforcing it may delay or loss if assets are missing or pledged. The token standard can't repair broken custody record or a missing title.
<br><br><br>

---

## B. Attestation — how the chain learns the truth (plank b)

**B1.** `attest()` is the only function that moves the NAV, and it is gated by `REPORTER_ROLE`.
Everything downstream — subscription pricing, redemption payouts, both invariants — believes that
number. Name the failure modes of a single trusted reporter, and one mechanism (technical,
financial, or legal) that mitigates each.

> Your answer:
First, the reporter may submit an incorrect NAV because of a calculation error or a misunderstanding of the fund's liabilities. Independent valuation, reconciliation against official fund records, and a second-person review can reduce this risk.
Second, the reporter may deliberately overstate or understate NAV to shift value among subscribers, redeemers, and continuing holders. Threshold multisig ensures that no single key can change the price alone. Separating the person who prepares the figure from the person who signs the transaction further reduces the risk of unilateral manipulation. A delayed-effective attestation, published before it takes effect, can also give stakeholders time to respond.
Third, the reporter and an administrator may collude, compromising two trusted roles at once. No single technical control can reliably detect every form of collusion. Contractual liability for negligent or fraudulent reporting, together with audit rights, creates financial and legal consequences. Separating the reporter from the operator and conducting regular independent audits also make collusion harder to conceal and more costly to attempt.
<br><br><br>

**B2.** A production feed would check whether `updatedAt` is stale; this lab's mock does not. A
**frozen** NAV is a different attack from a **wrong** NAV. Describe how a stale-but-honest NAV can
be exploited by someone who knows the true value has moved.

> Your answer:
A stale NAV can be exploited even when the reporter is honest, because the problem is delay instead of fraud. Suppose the reported NAV is $1.00 and the true value of the T-Bills later falls to $0.97, subscriptions and redemptions still use the old figure trade at a price that no longer matches the fund. Someone who knows the true value has fallen can redeem at the stale and higher price before the update. The attacker does not need to corrupt the reporter, only to act before the next honest update. The fund then pays more than those shares are worth, and holders who stay absorb the lost. If the true NAV rises while the reported NAV stays low, the same person can subscribe cheaply and dilute existing holders.
This is different from posting a false NAV. The reported number may have been right when it was calculated, and no longer current. A production contract should reject an update older than a set threshold, and should pause subscriptions and redemptions when the feed goes stale, with a stated rule for requests already in the queue.
<br><br><br>

---

## C. Redemption — T+1 does not settle on-chain (plank c)

**C1.** The queue locks the payout at the NAV of **enqueue** time, not **settle** time. If the NAV
rises between the two, who gains and who loses — the redeemer, or the holders who stayed? Is that
the right allocation of risk, and how would you change it?

> Your answer:
If the payout is locked at enqueue and NAV rises before settlement, the redeemer is paid the lower, earlier value. Holders who stayed gain, because the fund does not have to pay the higher settlement-time value. The redeemer loses the appreciation earned during the wait. If NAV falls, the direction reverses. The redeemer may still receive the higher enqueue-time amount, and the holders who stayed bear the decline. Price risk during the queue is shifted between the redeemer and the remaining fund.
Whether that split is right depends on what the product promised. A fixed enqueue price gives the redeemer certainty, which matters when settlement takes a day. It can also be unfair to continuing holders and may encourage people to queue when they expect NAV to move against the fund.
I would price the payout at settlement, so the redemption matches the value when assets are actually set aside. However, settlement-time NAV is not automatically more reliable, it is still based on the latest `attest()` report, which may be stale or inaccurate. The contract should define how to handle delayed settlement and stale NAV, rather than assuming that using the later price alone resolves the risk.
<br><br><br>

**C2.** In a 2008 money-market fund breaking the buck, and in USDC's 2023 depeg, redemptions were
handled very differently. Compare the two. For a tokenized T-Bill fund, what does it mean to "close
the redemption channel", and what should happen to the queue when it does? Then look at the lever
this lab actually ships: `pause()` (`PAUSER_ROLE`) freezes transfers, minting **and** redemption
together — one switch, no partial setting. Why is that the wrong tool for a liquidity squeeze, and
what would you rather have?

> Your answer:
In 2008, losses on Lehman Brothers debt caused the Reserve Primary Fund to break the buck. The fund suspended redemptions and moved toward liquidation, leaving investors uncertain about how much they would recover and when. In March 2023, USDC traded below $1 after Circle disclosed its exposure to Silicon Valley Bank. The banking disruption temporarily restricted access to reserve funds, so redemptions could not be paid until banking operations resumed. USDC then recovered toward $1. The Reserve Primary Fund suspended redemptions and entered liquidation. USDC's redemption terms stayed in place, but cash still could not arrive while the banking channel was down.
For a tokenized T-Bill fund, closing the redemption channel means stopping the settlement of redemption requests when cash, banking access, or verified liquidity is insufficient. It does not mean deleting queued claims or changing their order. The queue should preserve an auditable record, explain why settlement has stopped, and state whether existing requests retain their positions.
The lab's `pause()` is the wrong tool for this type of liquidity squeeze because it freezes transfers, minting, and redemption with one switch. A fund may need to stop cash outflows while allowing compliant transfers and corrections to continue. I would separate controls for transfers, subscriptions, and redemptions, introduce a dedicated redemption pause, and require emergency powers to expire unless renewed.
<br><br><br>

---

## D. Admission — the guest list and the backdoor (plank d)

**D1.** Every balance change in `TBillToken._update` checks **both** endpoints against the
whitelist. That is what stops a sanctioned address from receiving shares — and also what stops a
completely ordinary user who has not finished KYC. Where is the right line for a regulated fund,
and who should be able to move it?

> Your answer:
A regulated fund has to block illegal holders without treating every unfinished application as a sanction. Checking both endpoints in `TBillToken._update` stops a sanctioned address from receiving or sending shares. The same check also stops an ordinary user who has not finished KYC, including someone whose documents are still in review or whose status was recorded wrongly.
The line should follow legal written standard rather than an administrator's preference. The fund should distinguish an address that the law prohibits, an address that has not finished onboarding, and an address that is only under review. An unverified address should not receive new shares, and recorded error should have an appeal and a way to correct it.
The power to move that line should be handed over to a compliance function bound by written policy, not to one unrestricted key. Each change should be authorized, emit an event, and be reviewable by someone who did not make it. Sanctions and court orders need fast restrictions, but that action should be logged and reviewed afterward. Admission can stay discretionary and still be explainable and reversible when it is wrong. 
<br><br><br>

**D2.** A regulated fund asks for two levers: freeze an address (`setWhitelisted(addr, false)`) and
burn a balance (`MINTER_ROLE`) — both censorship tools, both justified by the product. But Ex4.3
shows the two **collide**: once an address is off the list, `burn()` reverts as well, because
`_update` guards both endpoints. So a freeze also blocks a seizure. Argue **both** sides of handing
an issuer these powers, then say what safeguards you would add and who should hold each key.

> Your answer:
An issuer can justify both levers. Freezing an address can stop transfers to a sanctioned wallet, a stolen-token account, or a holder under a court order. Burning can correct some errors or carry out a recovery the law authorizes. Without those powers, a regulated fund may be unable to meet a fraud or sanctions duty.
But the same powers are easy to abuse. An issuer could freeze a legitimate investor without a stated reason, censor selected transfers, or burn a balance without evidence or process. The lab adds a technical collision, because `_update` checks both endpoints, taking an address off the whitelist also makes `burn()` revert. A freeze then blocks the seizure it was supposed to enable.
I would separate normal transfers from recovery. A narrow seizure function could skip the whitelist check, but it must state a legal reason and emit a clear event. I would also split the keys across roles. The compliance team holds the whitelist key and can freeze addresses, but only under written policy. The minter key is split, one for ordinary corrections, held by a compliance officer and another for legal seizure, needing a court order or a legal officer's approval. The admin role belongs to a governance body that holds no operation key, so the people who manage the keys cannot use them for their own ends. Emergency powers should be limited and reviewed later. 
<br><br><br>

---

## E. Tests (Tier 1 required — this is Ex2, Ex3 and Ex4)

Turn the red tests green in `test/exercises/01_BridgeTasks.t.sol` to cover the scenarios below, and
write your test function names here:

| Plank | Scenario                                                             | Your test function name                             |
| ----- | -------------------------------------------------------------------- | --------------------------------------------------- |
| a     | Shares exist while the custodian holds nothing                       | `test_Ex2_SharesExistWhileTheCustodianHoldsNothing` |
| a     | `realHoldings()` moves with no cash moving                           | `test_Ex2_RealHoldingsIsJustANumber`                |
| b     | The claim value floats while the share count stays                   | `test_Ex3_TheClaimFloats_TheShareCountDoesNot`      |
| b     | One `attest` re-prices every holder at once                          | `test_Ex3_OneCallMovesTheWholeBook`                 |
| d     | A non-whitelisted address cannot receive shares, even by paying      | `test_Ex4_NoKyc_NoShares_EvenIfYouPay`              |
| d     | A whitelisted holder cannot send shares to a non-whitelisted address | `test_Ex4_TransferChecksBothEndpoints`              |
| d     | Removing an address freezes that holder — and blocks a burn          | `test_Ex4_FreezeBeatsConfiscation`                  |

Then write one more scenario you consider **most likely to be exploited** on a tokenized fund, and
say which plank it breaks:

> Your answer:
The scenario I would most expect to be exploited is a stale or manipulated NAV with the redemption channel still open. If the reported NAV is higher than the true value of the assets, a holder who knows that can redeem before the figure is corrected. The fund pays out more than those shares represent, and the loss falls on holders who stay. That breaks plank B, Attestation, because the contract treats an unreliable price as fact. It also hits plank C, Redemption, because the queue turns that price into a cash obligation.
Two things widen the opening. First, a single reporter can call `attest()` with no second check, so one compromised or careless key moves the price. Second, the contract accepts a stale `updatedAt`, so an outdated figure stays in force indefinitely. The fix is to treat freshness as a security property, which require a recent attestation from an independent source, pause subscriptions and redemptions when the NAV is stale, and state clearly how already-queued requests are handled. Reported NAV should also be reconciled against custody records, because a correct contract cannot repair a wrong off-chain fact. 