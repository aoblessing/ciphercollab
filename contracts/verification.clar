;; CipherCollab Verification Contract
;; Extended proof structure and verification

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-PROOF-EXISTS (err u402))
(define-constant ERR-PROOF-NOT-FOUND (err u403))
(define-constant ERR-INVALID-PROOF (err u404))
(define-constant ERR-INVALID-VERIFICATION (err u405))

;; Data Maps

;; Store verification proofs
(define-map proofs
  { project-id: uint, proof-id: uint }
  {
    submitter: principal,
    proof-hash: (buff 32),
    data-hash: (buff 32),
    timestamp: uint,
    verification-params: (string-utf8 1024),
    is-verified: bool,
    verifier: (optional principal),
    verification-time: (optional uint)
  }
)

;; Store verifier credentials
(define-map verifiers
  { address: principal }
  {
    reputation: uint,
    verification-count: uint,
    registered-at: uint,
    is-active: bool
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

;; Check if caller is authorized to verify proofs
(define-private (is-authorized-verifier)
  (let (
    (verifier-data (map-get? verifiers { address: tx-sender }))
  )
    (match verifier-data
      v (and (get is-active v) true)
      false
    )
  )
)

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
  (data-hash (buff 32))
  (verification-params (string-utf8 1024)))
  
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
        verification-params: verification-params,
        is-verified: false,
        verifier: none,
        verification-time: none
      }
    )
    
    (ok proof-id)
  )
)

;; Register a new verifier
(define-public (register-verifier (address principal))
  (begin
    ;; Only contract owner can register verifiers
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    
    ;; Register the verifier
    (map-set verifiers
      { address: address }
      {
        reputation: u0,
        verification-count: u0,
        registered-at: block-height,
        is-active: true
      }
    )
    
    (ok true)
  )
)

;; Read-only Functions

;; Get proof details
(define-read-only (get-proof (project-id uint) (proof-id uint))
  (map-get? proofs { project-id: project-id, proof-id: proof-id })
)

;; Get verifier details
(define-read-only (get-verifier (address principal))
  (map-get? verifiers { address: address })
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
