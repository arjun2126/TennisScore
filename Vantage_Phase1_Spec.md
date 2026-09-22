# Vantage — Two-Sided Tennis Event Platform — Phase 1 Spec (Week 0)

Canonical architecture + compliance contract. Source of truth for Phases 2–9.
Compliance decisions here bind later phases (Standing Rule 1).

---

## 1. One-Page Product Spec

**Who:** Creators (run events, monetize) and Players (browse, join, pay, play, rank).

**Core loop:**
CREATE → PUBLISH (private or public w/ moderation queue) → BROWSE (public; phase 3)
→ JOIN + PAY via Apple In-App Purchase → PLAY (schedule/score/standings) → RATED (skill)
→ REFUND/EXPORT (trust + payouts).

**Event types + wizard fields (create flow, 5 steps):**

| Step | Fields |
|---|---|
| 1 Type | Tournament · League · Ladder · Custom preset |
| 2 Details | Name, summary, photo, dates (start/end/reg-deadline), location (label + lat/lon), maxPlayers |
| 3 Rules | Format preset or custom (sets/tiebreak/group size), skill band (min–max), age band (min–max, **min 13; public min 18**) |
| 4 Fees | Entry fee ($), convenience fee mode (%1 default **15%**  or flat **$3**, creator-configurable), live breakdown preview |
| 5 Visibility & Publish | Private (link/QR) · Public (**admin review queue**); minor-attestation checkbox if ageMin < 18; PUBLISH |

**Monetization (MVP):** Convenience fee collected via IAP on entry. **Settlement = Path 1 (manual):** all IAP revenue lands in the Apple developer account; app tracks creator-owed `entry fee` portion locally (Creator Dashboard mock payout logs a transaction; you do PayPal manually). No backend money movement (Cart-Before-Cat, Rule 6).

---

## 2. Data Model Changes

**`Event`** (new, SwiftData, iOS target): `id`, `name`, `summary`, `eventTypeRaw` (tournament/league/ladder/custom), `rulesDetail`, `maxPlayers`, `startDate`, `endDate`, `regDeadline`, `locationLabel`, `latitude`, `longitude`, `skillMin`, `skillMax`, `ageMin`, `ageMax` (default 18), `visibilityRaw` (private/public), `statusRaw` (draft/published/cancelled/completed), `entryFeeCents`, `feeModeRaw` (percent/flat), `convenienceFeePercent` (15), `convenienceFeeFlatCents` (300), `ratingOn`, `attestMinorConsent`, `shareToken`, `createdAt`, `createdByPlayerID`, `createdByName`. Computed: `convenienceFeeCents`, `totalCents`, `isMinorSpace` (ageMin < 18).

**`EventRegistration`** (Phase 3): `event`, `player`, `status` (pending/confirmed/refunded/cancelled/waitlisted), `paymentRecord`, `joinedAt`.

**`PaymentRecord`** (Phase 4): `appleTransactionID`, `productID`, `appAccountToken`, `event`, `registration`, `totalCents`, `entryCents`, `feeCents`, `status` (purchased/refundRequested/refunded).

**`Player` additions** (Phase 6): `ratingSingles` (Glicko-2 `(r, rd, vol)`), `ratingBandJ/A`, `ratingProvisional`, public-rating toggle.

**`Match` additions** (Phase 6): `isRated`, `ratingDeltaSingle` per player, `ageBand`, `eventID`.

**`ModerationReport`** (Phase 3/8): `subjectType`, `subjectID`, `reporterID`, `reason`, `status`.

Pure-logic modules reused/test-first: `DrawEngine` (scheduling), new `RatingsEngine` (Elo/Glicko-2), new `EventFee.pure` (fee/breakdown math).

---

## 3. Payment Flow (Apple IAP — RevenueCat) + Fee Split + Refunds

```
Player taps JOIN
   → Checkout: [Entry fee $25] + [Convenience fee $3] = [Total $28]   (exact line items)
   → RevenueCat/SKProduct purchase (product id event.<id>.entry, appAccountToken)
   → Server-side receipt/entitlement verification
   → Confirmed registration + schedule/score access granted (entitlement)
Settlement:
   Apple remits $28 − (15%/30%) to developer account
   → entry-fee portion = creator payout (manual PayPal, tracked in Creator Dashboard)
   → convenience fee = platform revenue
Refunds (pre-event only, MVP; post-event = creator discretion):
   Player/creator requests refund → App Store refund path → RC webhook (REVOKED)
   → revert entitlement, cancel registration, release spot; payout ledger reversed.
Restore: "Restore Purchases" in Settings re-grants valid entitlements.
```

**App Store compliance callouts:** (1) ALL entry/convenience fees via Apple IAP — **no Stripe** in-app (3.1.1); (2) full nondisclosed fee breakdown before `Purchase`; (3) refund path + Apple reportaproblem link present (3.1.1 refund); (4) restore purchases; (5) payout tooling lives outside app commerce (real-world payment OK); (6) Creator gifts/discounts must not bypass IAP.

---

## 4. App Store Compliance Checklist (binding, per-phase owner)

| Risk | Mitigation (actionable) | Phase |
|---|---|---|
| Payment routing (digital goods) | IAP ONLY (RevenueCat or StoreKit 2); zero Stripe in-app | 4 |
| Fee disclosure | Checkout shows `entry + fee = total` before purchase; fee never hidden | 4 |
| Refunds | In-app refund request + support link; RC webhook revocation gradient; pre-event auto-refund policy text | 4 |
| Restore purchases | Settings button re-granting entitlements | 4 |
| UGC (events, scores, later chat) | Report/flag on every public entity; admin review queue for public events; block users | 3, 8 |
| Privacy (PII) | No email/phone on event pages; min-PII profile; Delete Account in Settings erases data; privacy policy + ToS links | 3, 8 |
| ATT/analytics | No analytics, or opt-in with ATT prompt before any tracking | 8 |
| Age gating | Public events 18+; 13–17 only private with creator attestation "I confirm parental consent for all minors" | 2, 3, 6, 8 |
| Content moderation | Admin dashboard (flag queue, ban), demonstrated in Review | 3, 8 |
| Payout tracking | Creator Dashboard (entry/pending/history) + Phase 8 CSV export; manual PayPal | 4, 8 |

---

## 5. Week 6 MVP Acceptance Criteria

1. Create tournament/league/ladder/custom event; save to SwiftData; appears in list. (P2)
2. Shareable deep link `vantage://event/<token>` + QR opens event detail. (P2)
3. Public events only after policy gate (18+); minor-attestation enforced for private 13–17. (P2)
4. Browse/filter public events; join with full fee-breakdown mock checkout. (P3)
5. Report/flag on every public event; creator cancels; waitlist. (P3)
6. Real IAP purchase → confirmed spot; creator refund; restore purchases; fee split logged. (P4)
7. Creator Dashboard shows `entry_fees_collected`, `platform_fee`, `pending_payout`, `payout_history` + mock payout. (P4)
8. Schedule auto-gen + score entry + live standings + dispute flag. (P5)
9. Rated events update singles Elo/Glicko (junior/adult bands); profile shows rating + history; privacy toggle. (P6)
10. iOS + Watch build SUCCEEDED, zero warnings; Phase 1–6 acceptance all green. (P1–6)

---

## 6. Flagged Ambiguities (tracked; decided safely; revisit triggers noted)

1. **PaymentSDK: RevenueCat vs StoreKit 2.** Compliance equal (both IAP). MVP builds raw **StoreKit 2 (zero external-dep, ships offline)**; RC adoption deferred until subscription/premium/modern cross-platform admin needed. Flag: if a paying beta runs before RC, entitlements verify server-side regardless of SDK.
2. **"Private" vs "Public" at creation.** Private events = link-invite + a roster; there is NO public browse until Phase 3. Public creation allowed in P2 but consumers gate it. No UGC exposure pre-moderation.
3. **Creator pays vs player pays fee:** settled prior — **player pays entry+fee=total at checkout; platform nets fee; creator receives entry portion**; shown on both checkout and dashboard.
4. **Junior COPPA line:** 18+ enforced for public; 13–17 private-only with creator attestation. Parent-account/verifiable consent flow deferred to Phase 8 prep — flag persists until parental flow ships; do NOT advertise junior public events until then.
5. **Blocking/ban university**: moderation is server-side in prod; MVP uses local admin queue + report log; staffing owner = platform operator (you) — document in Review notes.
6. **No backend (local-only SwiftData)** for money: settlement ledger is local until Phase 8 CSV; Apple receives IAP revenue directly. Acceptable for pilot ≤10 creators; revisit before scale.
7. **Real-world vs digital fee (3.1.1 vs 3.1.3(e)):** we route everything via IAP (defensible); monitor precedent changes.