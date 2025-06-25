;; Corrective Action Contract
;; Manages corrective action plans and implementation

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-UNAUTHORIZED (err u400))
(define-constant ERR-ACTION-NOT-FOUND (err u401))
(define-constant ERR-INVALID-STATUS (err u402))
(define-constant ERR-ASSESSMENT-NOT-FOUND (err u403))

;; Data Variables
(define-data-var next-action-id uint u1)

;; Data Maps
(define-map corrective-actions
  { action-id: uint }
  {
    assessment-id: uint,
    finding-id: uint,
    title: (string-ascii 200),
    description: (string-ascii 1000),
    assigned-to: principal,
    due-date: uint,
    priority: (string-ascii 20),
    status: (string-ascii 20),
    completion-date: (optional uint),
    completion-notes: (string-ascii 500),
    created-at: uint,
    created-by: principal
  }
)

(define-map action-updates
  { action-id: uint, update-id: uint }
  {
    update-text: (string-ascii 500),
    progress-percentage: uint,
    updated-at: uint,
    updated-by: principal
  }
)

;; Public Functions

;; Create corrective action
(define-public (create-action (assessment-id uint) (finding-id uint) (title (string-ascii 200)) (description (string-ascii 1000)) (assigned-to principal) (due-date uint) (priority (string-ascii 20)))
  (let ((action-id (var-get next-action-id)))
    (map-set corrective-actions
      { action-id: action-id }
      {
        assessment-id: assessment-id,
        finding-id: finding-id,
        title: title,
        description: description,
        assigned-to: assigned-to,
        due-date: due-date,
        priority: priority,
        status: "open",
        completion-date: none,
        completion-notes: "",
        created-at: block-height,
        created-by: tx-sender
      }
    )
    (var-set next-action-id (+ action-id u1))
    (ok action-id)
  )
)

;; Update action progress
(define-public (update-action-progress (action-id uint) (update-id uint) (update-text (string-ascii 500)) (progress-percentage uint))
  (let ((action (unwrap! (map-get? corrective-actions { action-id: action-id }) ERR-ACTION-NOT-FOUND)))
    (asserts! (or (is-eq tx-sender (get assigned-to action)) (is-eq tx-sender CONTRACT-OWNER)) ERR-UNAUTHORIZED)
    (map-set action-updates
      { action-id: action-id, update-id: update-id }
      {
        update-text: update-text,
        progress-percentage: progress-percentage,
        updated-at: block-height,
        updated-by: tx-sender
      }
    )
    (ok true)
  )
)

;; Complete corrective action
(define-public (complete-action (action-id uint) (completion-notes (string-ascii 500)))
  (let ((action (unwrap! (map-get? corrective-actions { action-id: action-id }) ERR-ACTION-NOT-FOUND)))
    (asserts! (or (is-eq tx-sender (get assigned-to action)) (is-eq tx-sender CONTRACT-OWNER)) ERR-UNAUTHORIZED)
    (asserts! (is-eq (get status action) "open") ERR-INVALID-STATUS)
    (map-set corrective-actions
      { action-id: action-id }
      (merge action {
        status: "completed",
        completion-date: (some block-height),
        completion-notes: completion-notes
      })
    )
    (ok true)
  )
)

;; Verify action completion
(define-public (verify-action-completion (action-id uint))
  (let ((action (unwrap! (map-get? corrective-actions { action-id: action-id }) ERR-ACTION-NOT-FOUND)))
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (asserts! (is-eq (get status action) "completed") ERR-INVALID-STATUS)
    (map-set corrective-actions
      { action-id: action-id }
      (merge action { status: "verified" })
    )
    (ok true)
  )
)

;; Extend due date
(define-public (extend-due-date (action-id uint) (new-due-date uint))
  (let ((action (unwrap! (map-get? corrective-actions { action-id: action-id }) ERR-ACTION-NOT-FOUND)))
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (map-set corrective-actions
      { action-id: action-id }
      (merge action { due-date: new-due-date })
    )
    (ok true)
  )
)

;; Read-only Functions

;; Get corrective action details
(define-read-only (get-action (action-id uint))
  (map-get? corrective-actions { action-id: action-id })
)

;; Get action update
(define-read-only (get-action-update (action-id uint) (update-id uint))
  (map-get? action-updates { action-id: action-id, update-id: update-id })
)

;; Check if action is overdue
(define-read-only (is-action-overdue (action-id uint))
  (match (map-get? corrective-actions { action-id: action-id })
    action (and
      (not (is-eq (get status action) "completed"))
      (not (is-eq (get status action) "verified"))
      (> block-height (get due-date action))
    )
    false
  )
)

;; Get next action ID
(define-read-only (get-next-action-id)
  (var-get next-action-id)
)
