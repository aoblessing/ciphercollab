;; CipherCollab Core Contract
;; Manages research collaboration projects, participants, and basic workflow

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-PROJECT-EXISTS (err u402))
(define-constant ERR-PROJECT-NOT-FOUND (err u403))
(define-constant ERR-PARTICIPANT-EXISTS (err u404))
(define-constant ERR-PARTICIPANT-NOT-FOUND (err u405))
(define-constant ERR-INVALID-STATUS (err u406))
(define-constant ERR-PROJECT-LOCKED (err u407))

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
    metadata-url: (optional (string-utf8 256)),
    is-locked: bool
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

;; Track research contributions
(define-map contributions
  { project-id: uint, contribution-id: uint }
  {
    contributor: principal,
    title: (string-ascii 64),
    description: (string-utf8 500),
    timestamp: uint,
    proof-hash: (optional (buff 32)),
    verification-status: (string-ascii 20),
    metadata-url: (optional (string-utf8 256))
  }
)

;; Variables
(define-data-var last-project-id uint u0)

;; Map to track the last contribution ID for each project
(define-map last-contribution-id-map
  { project-id: uint }
  { last-id: uint }
)

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

(define-private (can-modify-project (project-id uint))
  (let (
    (project (unwrap! (map-get? projects { project-id: project-id }) false))
  )
    (and 
      (not (get is-locked project))
      (or 
        (is-project-owner project-id)
        (is-contract-owner)
      )
    )
  )
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
        metadata-url: metadata-url,
        is-locked: false
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
    
    ;; Initialize the contribution counter for this project
    (map-set last-contribution-id-map 
      { project-id: project-id }
      { last-id: u0 }
    )
    
    ;; Return the new project ID
    (ok project-id)
  )
)

;; Add a participant to a project
(define-public (add-participant (project-id uint) (participant principal) (role (string-ascii 20)))
  (begin
    ;; Check authorization
    (asserts! (can-modify-project project-id) ERR-NOT-AUTHORIZED)
    
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

;; Record a research contribution
(define-public (add-contribution (project-id uint) (title (string-ascii 64)) (description (string-utf8 500)) (proof-hash (optional (buff 32))) (metadata-url (optional (string-utf8 256))))
  (let (
    (current-last-id (default-to { last-id: u0 } (map-get? last-contribution-id-map { project-id: project-id })))
    (contribution-id (+ (get last-id current-last-id) u1))
  )
    ;; Check if project exists
    (asserts! (is-some (map-get? projects { project-id: project-id })) ERR-PROJECT-NOT-FOUND)
    
    ;; Check if user is a participant
    (asserts! (is-project-participant project-id tx-sender) ERR-NOT-AUTHORIZED)
    
    ;; Update the contribution counter for this project
    (map-set last-contribution-id-map 
      { project-id: project-id }
      { last-id: contribution-id }
    )
    
    ;; Record the contribution
    (map-set contributions
      { project-id: project-id, contribution-id: contribution-id }
      {
        contributor: tx-sender,
        title: title,
        description: description,
        timestamp: block-height,
        proof-hash: proof-hash,
        verification-status: "pending",
        metadata-url: metadata-url
      }
    )
    
    ;; Update participant's contribution count
    (let (
      (participant-data (unwrap! (map-get? project-participants { project-id: project-id, participant: tx-sender }) ERR-PARTICIPANT-NOT-FOUND))
      (new-count (+ (get contribution-count participant-data) u1))
    )
      (map-set project-participants
        { project-id: project-id, participant: tx-sender }
        (merge participant-data { contribution-count: new-count })
      )
    )
    
    (ok contribution-id)
  )
)

;; Update project status
(define-public (update-project-status (project-id uint) (new-status (string-ascii 20)))
  (begin
    ;; Check authorization
    (asserts! (can-modify-project project-id) ERR-NOT-AUTHORIZED)
    
    ;; Validate status string (simple validation, can be extended)
    (asserts! (or 
      (is-eq new-status "active") 
      (is-eq new-status "paused") 
      (is-eq new-status "completed")
      (is-eq new-status "archived")) 
      ERR-INVALID-STATUS)
    
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

;; Lock a project to prevent modifications
(define-public (lock-project (project-id uint))
  (begin
    ;; Only project owner or contract owner can lock a project
    (asserts! (or (is-project-owner project-id) (is-contract-owner)) ERR-NOT-AUTHORIZED)
    
    ;; Update the project lock status
    (let (
      (project (unwrap! (map-get? projects { project-id: project-id }) ERR-PROJECT-NOT-FOUND))
    )
      (map-set projects
        { project-id: project-id }
        (merge project { is-locked: true })
      )
    )
    
    (ok true)
  )
)

;; Unlock a project to allow modifications
(define-public (unlock-project (project-id uint))
  (begin
    ;; Only project owner or contract owner can unlock a project
    (asserts! (or (is-project-owner project-id) (is-contract-owner)) ERR-NOT-AUTHORIZED)
    
    ;; Update the project lock status
    (let (
      (project (unwrap! (map-get? projects { project-id: project-id }) ERR-PROJECT-NOT-FOUND))
    )
      (map-set projects
        { project-id: project-id }
        (merge project { is-locked: false })
      )
    )
    
    (ok true)
  )
)

;; Verify a contribution
(define-public (verify-contribution (project-id uint) (contribution-id uint) (verification-status (string-ascii 20)))
  (begin
    ;; Only project owner can verify contributions
    (asserts! (is-project-owner project-id) ERR-NOT-AUTHORIZED)
    
    ;; Validate verification status
    (asserts! (or 
      (is-eq verification-status "verified") 
      (is-eq verification-status "rejected") 
      (is-eq verification-status "pending-revisions")) 
      ERR-INVALID-STATUS)
    
    ;; Update the contribution verification status
    (let (
      (contribution (unwrap! (map-get? contributions { project-id: project-id, contribution-id: contribution-id }) ERR-PROJECT-NOT-FOUND))
    )
      (map-set contributions
        { project-id: project-id, contribution-id: contribution-id }
        (merge contribution { verification-status: verification-status })
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

;; Get contribution details
(define-read-only (get-contribution (project-id uint) (contribution-id uint))
  (map-get? contributions { project-id: project-id, contribution-id: contribution-id })
)

;; Get total contribution count for a project
(define-read-only (get-project-contribution-count (project-id uint))
  (match (map-get? last-contribution-id-map { project-id: project-id })
    count-data (get last-id count-data)
    u0
  )
)

;; Check if a principal is a participant in a project
(define-read-only (is-participant (project-id uint) (address principal))
  (is-some (map-get? project-participants { project-id: project-id, participant: address }))
)
