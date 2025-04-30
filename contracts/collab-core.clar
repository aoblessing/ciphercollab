;; CipherCollab Core Contract

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-PROJECT-EXISTS (err u402))
(define-constant ERR-PROJECT-NOT-FOUND (err u403))

;; Data Maps
;; Project data structure
(define-map projects
  { project-id: uint }
  {
    name: (string-ascii 64),
    description: (string-utf8 500),
    owner: principal,
    created-at: uint,
    status: (string-ascii 20)
  }
)

;; Variables
(define-data-var last-project-id uint u0)

;; Private Functions
(define-private (is-project-owner (project-id uint))
  (let (
    (project (unwrap! (map-get? projects { project-id: project-id }) false))
  )
    (is-eq (get owner project) tx-sender)
  )
)

(define-private (is-contract-owner)
  (is-eq tx-sender CONTRACT-OWNER)
)

;; Public Functions
;; Create a new research project
(define-public (create-project (name (string-ascii 64)) (description (string-utf8 500)))
  (let (
    (project-id (+ (var-get last-project-id) u1))
  )
    ;; Update the project counter
    (var-set last-project-id project-id)
    
    ;; Create the project entry
    (map-set projects
      { project-id: project-id }
      {
        name: name,
        description: description,
        owner: tx-sender,
        created-at: block-height,
        status: "active"
      }
    )
    
    ;; Return the new project ID
    (ok project-id)
  )
)

;; Update project status
(define-public (update-project-status (project-id uint) (new-status (string-ascii 20)))
  (begin
    ;; Check authorization
    (asserts! (or (is-project-owner project-id) (is-contract-owner)) ERR-NOT-AUTHORIZED)
    
    ;; Update the project status
    (let (
      (project (unwrap! (map-get? projects { project-id: project-id }) ERR-PROJECT-NOT-FOUND))
    )
      (map-set projects
        { project-id: project-id }
        (merge project { status: new-status })
      )
    )
    
    (ok true)
  )
)

;; Read-only Functions

;; Get project details
(define-read-only (get-project (project-id uint))
  (map-get? projects { project-id: project-id })
)
