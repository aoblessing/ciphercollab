;; CipherCollab Verification Contract
;; Basic verification structure

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-PROOF-EXISTS (err u402))
(define-constant ERR-PROOF-NOT-FOUND (err u403))

;; Data Maps

;; Store verification proofs
(define-map proofs
  { project-id: uint, proof-id: uint }
  {
    submitter: principal,
    proof-hash: (buff 32),
    data-hash: (buff 32),
    timestamp: uint,
    is-verified: bool
  }
)

;; Variables
(define-data-var collab-core-contract principal CONTRACT-OWNER)

;; Map to track the last proof ID for each project
(define-map last-proof-id-map
  { project-id: uint }
  { last-id: uint }
)

;; Private Functions

;; Public Functions

;; Set the collab-core contract address
(define-public (set-collab-core-contract (new-contract principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (var-set collab-core-contract new-contract)
    (ok true)
  )
)

;; Submit a proof for verification
(define-public (submit-proof 
  (project-id uint) 
  (proof-hash (buff 32)) 
  (data-hash (buff 32)))
  
  (let (
    (current-last-id (default-to { last-id: u0 } (map-get? last-proof-id-map { project-id: project-id })))
    (proof-id (+ (get last-id current-last-id) u1))
  )
    ;; Update the proof counter for this project
    (map-set last-proof-id-map 
      { project-id: project-id } 
      { last-id: proof-id }
    )
    
    ;; Record the proof
    (map-set proofs
      { project-id: project-id, proof-id: proof-id }
      {
        submitter: tx-sender,
        proof-hash: proof-hash,
        data-hash: data-hash,
        timestamp: block-height,
        is-verified: false
      }
    )
    
    (ok proof-id)
  )
)

;; Read-only Functions

;; Get proof details
(define-read-only (get-proof (project-id uint) (proof-id uint))
  (map-get? proofs { project-id: project-id, proof-id: proof-id })
)

;; Check if a proof is verified
(define-read-only (is-proof-verified (project-id uint) (proof-id uint))
  (let (
    (proof (map-get? proofs { project-id: project-id, proof-id: proof-id }))
  )
    (default-to false (get is-verified proof))
  )
)

;; Get total proof count for a project
(define-read-only (get-project-proof-count (project-id uint))
  (match (map-get? last-proof-id-map { project-id: project-id })
    count-data (get last-id count-data)
    u0
  )
)
