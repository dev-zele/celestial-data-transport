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
