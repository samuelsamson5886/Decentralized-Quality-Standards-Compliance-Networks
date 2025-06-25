;; Assessment Coordination Contract
;; Coordinates compliance assessments and audits

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-UNAUTHORIZED (err u300))
(define-constant ERR-ASSESSMENT-EXISTS (err u301))
(define-constant ERR-ASSESSMENT-NOT-FOUND (err u302))
(define-constant ERR-INVALID-STATUS (err u303))
(define-constant ERR-OFFICER-NOT-VERIFIED (err u304))

;; Data Variables
(define-data-var next-assessment-id uint u1)

;; Data Maps
(define-map assessments
  { assessment-id: uint }
  {
    standard-id: uint,
    assessed-entity: principal,
    assigned-officer: uint,
    scheduled-date: uint,
    completion-date: (optional uint),
    status: (string-ascii 20),
    score: (optional uint),
    findings: (string-ascii 1000),
    recommendations: (string-ascii 1000),
    created-at: uint,
    created-by: principal
  }
)

(define-map assessment-findings
  { assessment-id: uint, finding-id: uint }
  {
    requirement-id: uint,
    compliance-level: uint,
    notes: (string-ascii 500),
    severity: (string-ascii 20)
  }
)

;; Public Functions

;; Schedule a new assessment
(define-public (schedule-assessment (standard-id uint) (assessed-entity principal) (assigned-officer uint) (scheduled-date uint))
  (let ((assessment-id (var-get next-assessment-id)))
    ;; Verify officer is verified (would call compliance-officer-verification contract)
    (map-set assessments
      { assessment-id: assessment-id }
      {
        standard-id: standard-id,
        assessed-entity: assessed-entity,
        assigned-officer: assigned-officer,
        scheduled-date: scheduled-date,
        completion-date: none,
        status: "scheduled",
        score: none,
        findings: "",
        recommendations: "",
        created-at: block-height,
        created-by: tx-sender
      }
    )
    (var-set next-assessment-id (+ assessment-id u1))
    (ok assessment-id)
  )
)

;; Start assessment
(define-public (start-assessment (assessment-id uint))
  (let ((assessment (unwrap! (map-get? assessments { assessment-id: assessment-id }) ERR-ASSESSMENT-NOT-FOUND)))
    (asserts! (is-eq (get status assessment) "scheduled") ERR-INVALID-STATUS)
    (map-set assessments
      { assessment-id: assessment-id }
      (merge assessment { status: "in-progress" })
    )
    (ok true)
  )
)

;; Complete assessment
(define-public (complete-assessment (assessment-id uint) (score uint) (findings (string-ascii 1000)) (recommendations (string-ascii 1000)))
  (let ((assessment (unwrap! (map-get? assessments { assessment-id: assessment-id }) ERR-ASSESSMENT-NOT-FOUND)))
    (asserts! (is-eq (get status assessment) "in-progress") ERR-INVALID-STATUS)
    (map-set assessments
      { assessment-id: assessment-id }
      (merge assessment {
        status: "completed",
        completion-date: (some block-height),
        score: (some score),
        findings: findings,
        recommendations: recommendations
      })
    )
    (ok true)
  )
)

;; Add finding to assessment
(define-public (add-finding (assessment-id uint) (finding-id uint) (requirement-id uint) (compliance-level uint) (notes (string-ascii 500)) (severity (string-ascii 20)))
  (begin
    (asserts! (is-some (map-get? assessments { assessment-id: assessment-id })) ERR-ASSESSMENT-NOT-FOUND)
    (map-set assessment-findings
      { assessment-id: assessment-id, finding-id: finding-id }
      {
        requirement-id: requirement-id,
        compliance-level: compliance-level,
        notes: notes,
        severity: severity
      }
    )
    (ok true)
  )
)

;; Cancel assessment
(define-public (cancel-assessment (assessment-id uint))
  (let ((assessment (unwrap! (map-get? assessments { assessment-id: assessment-id }) ERR-ASSESSMENT-NOT-FOUND)))
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (map-set assessments
      { assessment-id: assessment-id }
      (merge assessment { status: "cancelled" })
    )
    (ok true)
  )
)

;; Read-only Functions

;; Get assessment details
(define-read-only (get-assessment (assessment-id uint))
  (map-get? assessments { assessment-id: assessment-id })
)

;; Get finding
(define-read-only (get-finding (assessment-id uint) (finding-id uint))
  (map-get? assessment-findings { assessment-id: assessment-id, finding-id: finding-id })
)

;; Check if assessment is completed
(define-read-only (is-assessment-completed (assessment-id uint))
  (match (map-get? assessments { assessment-id: assessment-id })
    assessment (is-eq (get status assessment) "completed")
    false
  )
)

;; Get next assessment ID
(define-read-only (get-next-assessment-id)
  (var-get next-assessment-id)
)
