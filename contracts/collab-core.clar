;; CipherCollab Core Contract

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-PROJECT-EXISTS (err u402))
(define-constant ERR-PROJECT-NOT-FOUND (err u403))
(define-constant ERR-PARTICIPANT-EXISTS (err u404))
(define-constant ERR-PARTICIPANT-NOT-FOUND (err u405))

;; Data Maps
;; Project data structure
(define-map projects
  { project-id: uint }
  {
    name: (string-ascii 64),
    description: (string-utf8 500),
    owner: principal,
    created-at: uint,
    status: (string-ascii 20),
    metadata-url: (optional (string-utf8 256))
  }
)

;; Project participants and their roles
(define-map project-participants
  { project-id: uint, participant: principal }
  {
    role: (string-ascii 20),
    joined-at: uint,
    contribution-count: uint,
    reputation-score: uint
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

(define-private (is-project-participant (project-id uint) (address principal))
  (is-some (map-get? project-participants { project-id: project-id, participant: address }))
)

;; Public Functions
;; Create a new research project
(define-public (create-project (name (string-ascii 64)) (description (string-utf8 500)) (metadata-url (optional (string-utf8 256))))
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
        status: "active",
        metadata-url: metadata-url
      }
    )
    
    ;; Add the creator as a participant with the owner role
    (map-set project-participants
      { project-id: project-id, participant: tx-sender }
      {
        role: "owner",
        joined-at: block-height,
        contribution-count: u0,
        reputation-score: u100
      }
    )
    
    ;; Return the new project ID
    (ok project-id)
  )
)

;; Add a participant to a project
(define-public (add-participant (project-id uint) (participant principal) (role (string-ascii 20)))
  (begin
    ;; Check authorization
    (asserts! (is-project-owner project-id) ERR-NOT-AUTHORIZED)
    
    ;; Check if participant already exists
    (asserts! (not (is-project-participant project-id participant)) ERR-PARTICIPANT-EXISTS)
    
    ;; Add the participant
    (map-set project-participants
      { project-id: project-id, participant: participant }
      {
        role: role,
        joined-at: block-height,
        contribution-count: u0,
        reputation-score: u50
      }
    )
    
    (ok true)
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

;; Get participant details
(define-read-only (get-participant (project-id uint) (participant principal))
  (map-get? project-participants { project-id: project-id, participant: participant })
)

;; Check if a principal is a participant in a project
(define-read-only (is-participant (project-id uint) (address principal))
  (is-some (map-get? project-participants { project-id: project-id, participant: address }))
)
