;; Celestial Data Transport System
;; A system for secure transmission of resources between cosmic entities

;; Galaxy Wide Transmission Registry
(define-map CosmicTransmissions
  { transmission-sequence: uint }
  {
    origin-entity: principal,
    target-entity: principal,
    payload-category: uint,
    energy-units: uint,
    transmission-status: (string-ascii 10),
    creation-block: uint,
    expiration-block: uint
  }
)

;; Core System Parameters
(define-constant COSMOS_OVERSEER tx-sender)
(define-constant FAULT_UNAUTHORIZED (err u100))
(define-constant FAULT_ALREADY_PROCESSED (err u102))
(define-constant FAULT_EXECUTION_FAILED (err u103))
(define-constant FAULT_ENTRY_MISSING (err u101))
(define-constant FAULT_BAD_FORMAT (err u105))
(define-constant STELLAR_CYCLE_LENGTH u1008)
(define-constant FAULT_SENDER_RESTRICTED (err u106))
(define-constant FAULT_PERIOD_LAPSED (err u107))
(define-constant FAULT_INVALID_SEQUENCE (err u104))


;; -------------------------------------------------------------
;; System Core Validation Functions
;; -------------------------------------------------------------

;; Reclaim Expired Transmission Energy
(define-public (reclaim-expired-energy (sequence-id uint))
  (begin
    (asserts! (verify-sequence-validity sequence-id) FAULT_INVALID_SEQUENCE)
    (let
      (
        (transmission-record (unwrap! (map-get? CosmicTransmissions { transmission-sequence: sequence-id }) FAULT_ENTRY_MISSING))
        (origin (get origin-entity transmission-record))
        (energy (get energy-units transmission-record))
        (end-time (get expiration-block transmission-record))
      )
      (asserts! (or (is-eq tx-sender origin) (is-eq tx-sender COSMOS_OVERSEER)) FAULT_UNAUTHORIZED)
      (asserts! (or (is-eq (get transmission-status transmission-record) "pending") (is-eq (get transmission-status transmission-record) "accepted")) FAULT_ALREADY_PROCESSED)
      (asserts! (> block-height end-time) (err u108)) ;; Must be expired
      (match (as-contract (stx-transfer? energy tx-sender origin))
        success
          (begin
            (map-set CosmicTransmissions
              { transmission-sequence: sequence-id }
              (merge transmission-record { transmission-status: "expired" })
            )
            (print {event: "energy_reclaimed", sequence-id: sequence-id, origin: origin, energy: energy})
            (ok true)
          )
        error FAULT_EXECUTION_FAILED
      )
    )
  )
)

;; Ensure Entity Separation
(define-private (ensure-entity-separation (entity principal))
  (and 
    (not (is-eq entity tx-sender))
    (not (is-eq entity (as-contract tx-sender)))
  )
)

;; Transmission Counter
(define-data-var transmission-sequence-counter uint u0)

;; Verify Sequence Validity
(define-private (verify-sequence-validity (sequence-id uint))
  (<= sequence-id (var-get transmission-sequence-counter))
)

;; Initiate Arbitration Procedure
(define-public (initiate-arbitration (sequence-id uint) (arbitration-reason (string-ascii 50)))
  (begin
    (asserts! (verify-sequence-validity sequence-id) FAULT_INVALID_SEQUENCE)
    (let
      (
        (transmission-record (unwrap! (map-get? CosmicTransmissions { transmission-sequence: sequence-id }) FAULT_ENTRY_MISSING))
        (origin (get origin-entity transmission-record))
        (target (get target-entity transmission-record))
      )
      (asserts! (or (is-eq tx-sender origin) (is-eq tx-sender target)) FAULT_UNAUTHORIZED)
      (asserts! (or (is-eq (get transmission-status transmission-record) "pending") (is-eq (get transmission-status transmission-record) "accepted")) FAULT_ALREADY_PROCESSED)
      (asserts! (<= block-height (get expiration-block transmission-record)) FAULT_PERIOD_LAPSED)
      (map-set CosmicTransmissions
        { transmission-sequence: sequence-id }
        (merge transmission-record { transmission-status: "disputed" })
      )
      (print {event: "arbitration_initiated", sequence-id: sequence-id, initiator: tx-sender, reason: arbitration-reason})
      (ok true)
    )
  )
)

;; Arbitrate Disputed Transmission
(define-public (arbitrate-transmission (sequence-id uint) (allocation-percentage uint))
  (begin
    (asserts! (verify-sequence-validity sequence-id) FAULT_INVALID_SEQUENCE)
    (asserts! (is-eq tx-sender COSMOS_OVERSEER) FAULT_UNAUTHORIZED)
    (asserts! (<= allocation-percentage u100) FAULT_BAD_FORMAT) ;; Percentage must be 0-100
    (let
      (
        (transmission-record (unwrap! (map-get? CosmicTransmissions { transmission-sequence: sequence-id }) FAULT_ENTRY_MISSING))
        (origin (get origin-entity transmission-record))
        (target (get target-entity transmission-record))
        (energy (get energy-units transmission-record))
        (target-share (/ (* energy allocation-percentage) u100))
        (origin-share (- energy target-share))
      )
      (asserts! (is-eq (get transmission-status transmission-record) "disputed") (err u112)) ;; Must be disputed
      (asserts! (<= block-height (get expiration-block transmission-record)) FAULT_PERIOD_LAPSED)

      ;; Transfer target share
      (unwrap! (as-contract (stx-transfer? target-share tx-sender target)) FAULT_EXECUTION_FAILED)

      ;; Transfer origin share
      (unwrap! (as-contract (stx-transfer? origin-share tx-sender origin)) FAULT_EXECUTION_FAILED)

      (map-set CosmicTransmissions
        { transmission-sequence: sequence-id }
        (merge transmission-record { transmission-status: "arbitrated" })
      )
      (print {event: "transmission_arbitrated", sequence-id: sequence-id, origin: origin, target: target, 
              target-share: target-share, origin-share: origin-share, allocation-percentage: allocation-percentage})
      (ok true)
    )
  )
)

