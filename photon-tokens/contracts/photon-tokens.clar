;; Photon - Quantum-Verified Social Impact Platform
;; Luminosity Tokens (LUM) with Impact Verification Protocol

;; Error Constants
(define-constant ERR-UNAUTHORIZED (err u1000))
(define-constant ERR-PROJECT-NOT-FOUND (err u1001))
(define-constant ERR-INSUFFICIENT-FUNDS (err u1002))
(define-constant ERR-INVALID-MILESTONE (err u1003))
(define-constant ERR-PROJECT-INACTIVE (err u1004))
(define-constant ERR-VALIDATOR-NOT-STAKED (err u1005))
(define-constant ERR-INSUFFICIENT-STAKE (err u1006))
(define-constant ERR-SENSOR-DATA-INVALID (err u1007))
(define-constant ERR-THRESHOLD-NOT-MET (err u1008))
(define-constant ERR-VALIDATION-EXPIRED (err u1009))
(define-constant ERR-ALREADY-VALIDATED (err u1010))
(define-constant ERR-PROJECT-COMPLETED (err u1011))
(define-constant ERR-EMERGENCY-ACTIVE (err u1012))

;; Contract Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant MINIMUM-STAKE u1000000) ;; 1 LUM token minimum stake
(define-constant VALIDATION-WINDOW u144) ;; ~24 hours in blocks
(define-constant MIN-VALIDATORS u3)
(define-constant QUANTUM-VERIFICATION-THRESHOLD u75) ;; 75% accuracy threshold

;; Fungible Token Definition
(define-fungible-token luminosity-token)

;; Data Variables
(define-data-var total-projects uint u0)
(define-data-var total-impact-verified uint u0)
(define-data-var quantum-protocol-active bool true)
(define-data-var emergency-pause bool false)
(define-data-var platform-fee-rate uint u250) ;; 2.5%

;; Data Maps
(define-map projects
  uint
  {
    creator: principal,
    title: (string-ascii 100),
    category: (string-ascii 50),
    target-amount: uint,
    raised-amount: uint,
    current-milestone: uint,
    total-milestones: uint,
    brightness-level: uint,
    spectrum-diversity: uint,
    persistence-score: uint,
    active: bool,
    completed: bool,
    quantum-verified: bool,
    sensor-address: (string-ascii 64),
    creation-block: uint
  }
)

(define-map project-milestones
  {project-id: uint, milestone: uint}
  {
    description: (string-ascii 200),
    funding-amount: uint,
    threshold-value: uint,
    sensor-type: (string-ascii 30),
    verification-data: (string-ascii 500),
    achieved: bool,
    verification-block: uint,
    validator-count: uint
  }
)

(define-map validator-stakes
  principal
  {
    staked-amount: uint,
    active-validations: uint,
    successful-validations: uint,
    failed-validations: uint,
    reputation-score: uint,
    last-validation-block: uint
  }
)

(define-map project-validations
  {validator: principal, project-id: uint, milestone: uint}
  {
    validation-result: bool,
    sensor-data-hash: (buff 32),
    validation-block: uint,
    stake-amount: uint,
    processed: bool
  }
)

(define-map user-contributions
  {user: principal, project-id: uint}
  {
    total-contributed: uint,
    token-balance: uint,
    brightness-earned: uint,
    spectrum-earned: uint,
    persistence-earned: uint,
    last-contribution-block: uint
  }
)

(define-map sensor-data-registry
  (buff 32)
  {
    project-id: uint,
    milestone: uint,
    sensor-reading: uint,
    timestamp: uint,
    location-hash: (buff 32),
    verified: bool,
    verification-count: uint
  }
)

(define-map constellation-connections
  {user1: principal, user2: principal}
  {
    shared-projects: uint,
    connection-strength: uint,
    collaborative-impact: uint,
    last-interaction: uint
  }
)

;; Helper Functions
(define-private (calculate-lum-tokens (amount uint) (category (string-ascii 50)))
  ;; Simple token calculation - could be enhanced with category-based multipliers
  (/ (* amount u100) u1000000) ;; 0.01% conversion rate
)

;; Owner Functions
(define-public (set-platform-fee-rate (new-rate uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (asserts! (<= new-rate u1000) (err u2000)) ;; Max 10% fee
    (ok (var-set platform-fee-rate new-rate))
  )
)

(define-public (toggle-emergency-pause)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (ok (var-set emergency-pause (not (var-get emergency-pause))))
  )
)

(define-public (set-quantum-protocol-status (active bool))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED) ;; Fixed: was ERR-AUTHORIZED
    (ok (var-set quantum-protocol-active active))
  )
)

;; Public Functions
(define-public (create-project 
  (title (string-ascii 100))
  (category (string-ascii 50))
  (target-amount uint)
  (total-milestones uint)
  (sensor-address (string-ascii 64))
)
  (let (
    (project-id (+ (var-get total-projects) u1))
  )
    (asserts! (not (var-get emergency-pause)) ERR-EMERGENCY-ACTIVE)
    (asserts! (> target-amount u0) (err u2001))
    (asserts! (> total-milestones u0) (err u2002))
    (asserts! (<= total-milestones u10) (err u2003))
    
    (map-set projects project-id
      {
        creator: tx-sender,
        title: title,
        category: category,
        target-amount: target-amount,
        raised-amount: u0,
        current-milestone: u1,
        total-milestones: total-milestones,
        brightness-level: u0,
        spectrum-diversity: u0,
        persistence-score: u0,
        active: true,
        completed: false,
        quantum-verified: false,
        sensor-address: sensor-address,
        creation-block: block-height
      }
    )
    
    (var-set total-projects project-id)
    (ok project-id)
  )
)

(define-public (contribute-to-project (project-id uint) (amount uint))
  (let (
    (project (unwrap! (map-get? projects project-id) ERR-PROJECT-NOT-FOUND))
    (current-contribution (default-to 
      {total-contributed: u0, token-balance: u0, brightness-earned: u0, 
       spectrum-earned: u0, persistence-earned: u0, last-contribution-block: u0}
      (map-get? user-contributions {user: tx-sender, project-id: project-id})
    ))
    (lum-tokens (calculate-lum-tokens amount (get category project)))
  )
    (asserts! (not (var-get emergency-pause)) ERR-EMERGENCY-ACTIVE)
    (asserts! (get active project) ERR-PROJECT-INACTIVE)
    (asserts! (not (get completed project)) ERR-PROJECT-COMPLETED)
    (asserts! (> amount u0) ERR-INSUFFICIENT-FUNDS)
    
    ;; Transfer STX from user to contract
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    ;; Mint LUM tokens to contributor
    (try! (ft-mint? luminosity-token lum-tokens tx-sender))
    
    ;; Update project
    (map-set projects project-id
      (merge project {raised-amount: (+ (get raised-amount project) amount)})
    )
    
    ;; Update user contribution
    (map-set user-contributions {user: tx-sender, project-id: project-id}
      (merge current-contribution {
        total-contributed: (+ (get total-contributed current-contribution) amount),
        token-balance: (+ (get token-balance current-contribution) lum-tokens),
        last-contribution-block: block-height
      })
    )
    
    (ok lum-tokens)
  )
)

(define-public (stake-for-validation (stake-amount uint))
  (let (
    (current-stake (default-to 
      {staked-amount: u0, active-validations: u0, successful-validations: u0,
       failed-validations: u0, reputation-score: u100, last-validation-block: u0}
      (map-get? validator-stakes tx-sender)
    ))
  )
    (asserts! (>= stake-amount MINIMUM-STAKE) ERR-INSUFFICIENT-STAKE)
    (asserts! (>= (ft-get-balance luminosity-token tx-sender) stake-amount) ERR-INSUFFICIENT-FUNDS)
    
    ;; Lock tokens for staking
    (try! (ft-transfer? luminosity-token stake-amount tx-sender (as-contract tx-sender)))
    
    (map-set validator-stakes tx-sender
      (merge current-stake {
        staked-amount: (+ (get staked-amount current-stake) stake-amount)
      })
    )
    
    (ok true)
  )
)

(define-public (submit-sensor-data 
  (project-id uint) 
  (milestone uint) 
  (sensor-reading uint) 
  (location-hash (buff 32))
  (data-hash (buff 32))
)
  (let (
    (project (unwrap! (map-get? projects project-id) ERR-PROJECT-NOT-FOUND))
    (milestone-data (unwrap! (map-get? project-milestones {project-id: project-id, milestone: milestone}) ERR-INVALID-MILESTONE))
  )
    (asserts! (not (var-get emergency-pause)) ERR-EMERGENCY-ACTIVE)
    (asserts! (get active project) ERR-PROJECT-INACTIVE)
    (asserts! (is-eq (get current-milestone project) milestone) ERR-INVALID-MILESTONE)
    (asserts! (var-get quantum-protocol-active) (err u2004))
    
    (map-set sensor-data-registry data-hash
      {
        project-id: project-id,
        milestone: milestone,
        sensor-reading: sensor-reading,
        timestamp: block-height,
        location-hash: location-hash,
        verified: false,
        verification-count: u0
      }
    )
    
    (ok data-hash)
  )
)

(define-public (validate-milestone 
  (project-id uint) 
  (milestone uint) 
  (validation-result bool) 
  (sensor-data-hash (buff 32))
)
  (let (
    (validator-stake (unwrap! (map-get? validator-stakes tx-sender) ERR-VALIDATOR-NOT-STAKED))
    (project (unwrap! (map-get? projects project-id) ERR-PROJECT-NOT-FOUND))
    (sensor-data (unwrap! (map-get? sensor-data-registry sensor-data-hash) ERR-SENSOR-DATA-INVALID))
    (validation-key {validator: tx-sender, project-id: project-id, milestone: milestone})
    (existing-validation (map-get? project-validations validation-key))
  )
    (asserts! (> (get staked-amount validator-stake) u0) ERR-INSUFFICIENT-STAKE)
    (asserts! (get active project) ERR-PROJECT-INACTIVE)
    (asserts! (is-eq (get current-milestone project) milestone) ERR-INVALID-MILESTONE)
    (asserts! (is-none existing-validation) ERR-ALREADY-VALIDATED)
    (asserts! (< (- block-height (get timestamp sensor-data)) VALIDATION-WINDOW) ERR-VALIDATION-EXPIRED)
    
    ;; Record validation
    (map-set project-validations validation-key
      {
        validation-result: validation-result,
        sensor-data-hash: sensor-data-hash,
        validation-block: block-height,
        stake-amount: (get staked-amount validator-stake),
        processed: false
      }
    )
    
    ;; Update validator stats
    (map-set validator-stakes tx-sender
      (merge validator-stake {
        active-validations: (+ (get active-validations validator-stake) u1),
        last-validation-block: block-height
      })
    )
    
    ;; Update sensor data verification count
    (map-set sensor-data-registry sensor-data-hash
      (merge sensor-data {
        verification-count: (+ (get verification-count sensor-data) u1)
      })
    )
    
    (ok true)
  )
)

;; Read-only Functions
(define-read-only (get-project (project-id uint))
  (map-get? projects project-id)
)

(define-read-only (get-project-milestone (project-id uint) (milestone uint))
  (map-get? project-milestones {project-id: project-id, milestone: milestone})
)

(define-read-only (get-validator-stake (validator principal))
  (map-get? validator-stakes validator)
)

(define-read-only (get-user-contribution (user principal) (project-id uint))
  (map-get? user-contributions {user: user, project-id: project-id})
)

(define-read-only (get-sensor-data (data-hash (buff 32)))
  (map-get? sensor-data-registry data-hash)
)

(define-read-only (get-total-projects)
  (var-get total-projects)
)

(define-read-only (get-platform-fee-rate)
  (var-get platform-fee-rate)
)

(define-read-only (is-emergency-paused)
  (var-get emergency-pause)
)

(define-read-only (get-token-balance (user principal))
  (ft-get-balance luminosity-token user)
)