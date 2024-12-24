;; art_management.clar
;; Art Management Smart Contract
;; A Clarity 6.0 smart contract for managing an art gallery, allowing artwork minting, updating, 
;; ownership transfers, and batch artwork management.

;; Constants
(define-constant gallery-admin tx-sender) ;; The address of the gallery admin
(define-constant err-not-admin (err u200)) ;; Error for non-admin callers
(define-constant err-not-art-owner (err u201)) ;; Error when sender is not the artwork owner
(define-constant err-art-exists (err u202)) ;; Error when artwork already exists
(define-constant err-art-not-found (err u203)) ;; Error when artwork is not found
(define-constant err-invalid-art-details (err u204)) ;; Error for invalid artwork details
(define-constant err-max-batch-size (err u205)) ;; Error when batch size exceeds max limit
(define-constant max-art-batch u50) ;; Maximum number of artworks that can be added in one batch

;; Data Variables
(define-non-fungible-token art-token uint) ;; Non-fungible token representing artwork
(define-data-var latest-art-id uint u0) ;; Stores the ID of the latest minted artwork

;; Maps
(define-map art-details uint (string-ascii 512)) ;; Maps artwork ID to its details
(define-map art-transfers uint bool) ;; Maps artwork ID to its transfer status (true if transferred)

;; Private Functions
(define-private (is-art-owner (art-id uint) (sender principal))
    ;; Checks if the sender is the owner of the artwork with the given ID
    (is-eq sender (unwrap! (nft-get-owner? art-token art-id) false)))

(define-private (is-valid-details (details (string-ascii 512)))
    ;; Validates the length of the artwork details (should be between 1 and 512 characters)
    (let ((details-length (len details)))
        (and (>= details-length u1)
             (<= details-length u512))))

(define-private (is-transferred (art-id uint))
    ;; Checks if the artwork has been transferred by looking it up in the transfer map
    (default-to false (map-get? art-transfers art-id)))

(define-private (mint-art (details-data (string-ascii 512)))
    ;; Mints a new artwork with the provided details and assigns it a unique ID
    (let ((art-id (+ (var-get latest-art-id) u1))) ;; Increment the latest artwork ID
        (asserts! (is-valid-details details-data) err-invalid-art-details) ;; Ensure details are valid
        (try! (nft-mint? art-token art-id tx-sender)) ;; Mint the artwork NFT
        (map-set art-details art-id details-data) ;; Store the artwork details
        (var-set latest-art-id art-id) ;; Update the latest artwork ID
        (ok art-id)))

(define-private (mint-art-batch (details (string-ascii 512)) (previous-results (list 50 uint)))
;; Helper function to mint a batch of artworks
(match (mint-art details)
    success (unwrap-panic (as-max-len? (append previous-results success) u50)) ;; Ensure no overflow
    error previous-results)) ;; Return previous results in case of error

(define-private (encrypt-details (details (string-ascii 512)))
;; Encrypts art details before storing
(ok details)) ;; Placeholder

(define-private (art-id-response (id uint))
    ;; Helper function to format the response for an artwork
    {
        art-id: id,
        details: (unwrap-panic (get-art-details id)),
        owner: (unwrap-panic (get-art-owner id)),
        transferred: (unwrap-panic (is-art-transferred id))
    })

(define-private (generate-art-list (start uint) (count uint))
    ;; Helper function to generate a list of artwork IDs starting from a given ID
    (map + 
        (list start) 
        (create-sequence count)))

(define-private (create-sequence (length uint))
    ;; Helper function to create a sequence of artwork IDs
    (map - (list length)))

;; Optimizes the transfer-art function to reuse common logic
(define-private (validate-art-transfer (art-id uint) (sender principal) (recipient principal))
  ;; Validates transfer conditions for artwork
  (let ((current-owner (unwrap! (nft-get-owner? art-token art-id) err-not-art-owner)))
    (begin
      (asserts! (is-eq current-owner sender) err-not-art-owner)
      (asserts! (is-eq recipient tx-sender) err-not-art-owner)
      (asserts! (not (is-transferred art-id)) err-art-not-found)
      (ok true))))

;; Refactors the validation logic for better performance
(define-private (is-admin)
  ;; Checks if the caller is the admin
  (is-eq tx-sender gallery-admin))

;; Adds utility for checking if an ID is within valid range
(define-private (is-valid-art-id (art-id uint))
  ;; Checks if the provided artwork ID is valid
  (and (> art-id u0)
       (<= art-id (var-get latest-art-id))))


;; Public Functions
(define-public (add-artwork (details-data (string-ascii 512)))
    (begin
        ;; Public function to add a new artwork by the gallery admin
        (asserts! (is-eq tx-sender gallery-admin) err-not-admin) ;; Check if caller is admin
        (asserts! (is-valid-details details-data) err-invalid-art-details) ;; Validate artwork details
        (mint-art details-data))) ;; Mint the new artwork

(define-public (batch-add-artwork (details-list (list 50 (string-ascii 512))))
    (let ((batch-size (len details-list))) ;; Get the size of the batch
        (begin
            ;; Public function to add multiple artworks at once
            (asserts! (is-eq tx-sender gallery-admin) err-not-admin) ;; Ensure caller is admin
            (asserts! (<= batch-size max-art-batch) err-max-batch-size) ;; Ensure batch size is within limit
            (asserts! (> batch-size u0) err-max-batch-size) ;; Ensure batch has at least one artwork

            ;; Process each artwork detail in the batch
            (ok (fold mint-art-batch details-list (list))))))

(define-public (transfer-art (art-id uint) (sender principal) (recipient principal))
    (begin
        ;; Public function to transfer ownership of an artwork
        (asserts! (is-eq recipient tx-sender) err-not-art-owner) ;; Ensure the recipient is correct
        (asserts! (not (is-transferred art-id)) err-art-not-found) ;; Ensure artwork is not transferred yet
        (let ((current-owner (unwrap! (nft-get-owner? art-token art-id) err-not-art-owner))) ;; Get current owner
            (asserts! (is-eq current-owner sender) err-not-art-owner) ;; Ensure sender is the current owner
            (try! (nft-transfer? art-token art-id sender recipient)) ;; Transfer ownership
            (map-set art-transfers art-id true) ;; Mark the artwork as transferred
            (ok true))))

(define-public (update-art-details (art-id uint) (new-details (string-ascii 512)))
    (begin
        ;; Public function to update the details of an existing artwork
        (let ((art-owner (unwrap! (nft-get-owner? art-token art-id) err-art-not-found))) ;; Get artwork owner
            (asserts! (is-eq art-owner tx-sender) err-not-art-owner) ;; Ensure sender is the owner
            (asserts! (is-valid-details new-details) err-invalid-art-details) ;; Validate new details
            (map-set art-details art-id new-details) ;; Update the artwork details
            (ok true))))

(define-public (reserve-art-ids (count uint))
;; Reserves the next `count` artwork IDs without minting
(begin
    (asserts! (> count u0) err-invalid-art-details)
    (var-set latest-art-id (+ (var-get latest-art-id) count))
    (ok count)))

(define-public (test-transfer (art-id uint) (recipient principal))
;; Tests transferring artwork ownership
(transfer-art art-id tx-sender recipient))

(define-public (transfer-art-optimized (art-id uint) (recipient principal))
;; Optimized artwork transfer function
(let ((current-owner (unwrap! (nft-get-owner? art-token art-id) err-not-art-owner)))
    (begin
        (asserts! (is-eq tx-sender current-owner) err-not-art-owner)
        (asserts! (not (is-transferred art-id)) err-art-not-found)
        (try! (nft-transfer? art-token art-id tx-sender recipient))
        (map-set art-transfers art-id true)
        (ok true))))

(define-public (secure-update-details (art-id uint) (new-details (string-ascii 512)))
;; Allows updates only by the admin or the current owner
(let ((art-owner (unwrap! (nft-get-owner? art-token art-id) err-not-art-owner)))
    (asserts! (or (is-admin) (is-eq tx-sender art-owner)) err-not-admin)
    (asserts! (is-valid-details new-details) err-invalid-art-details)
    (map-set art-details art-id new-details)
    (ok true)))

(define-public (test-art-details (art-id uint))
;; Simple test to retrieve and validate artwork details
(ok (unwrap! (map-get? art-details art-id) err-art-not-found)))

;; Enhances batch minting by validating admin permission
(define-public (batch-mint-with-validation (details-list (list 50 (string-ascii 512))))
  ;; Mints multiple artworks in one batch after validating admin permission
  (let ((batch-size (len details-list)))
    (begin
      (asserts! (is-eq tx-sender gallery-admin) err-not-admin)
      (asserts! (> batch-size u0) err-max-batch-size)
      (asserts! (<= batch-size max-art-batch) err-max-batch-size)
      (ok (fold mint-art-batch details-list (list))))))

;; Read-Only Functions
(define-read-only (get-art-details (art-id uint))
    ;; Retrieves the details of a specific artwork by ID
    (ok (map-get? art-details art-id)))

(define-read-only (get-art-owner (art-id uint))
    ;; Retrieves the owner of a specific artwork by ID
    (ok (nft-get-owner? art-token art-id)))

(define-read-only (get-latest-art-id)
    ;; Retrieves the ID of the latest minted artwork
    (ok (var-get latest-art-id)))

(define-read-only (is-art-transferred (art-id uint))
    ;; Checks if a specific artwork has been transferred
    (ok (is-transferred art-id)))

(define-read-only (list-artworks (start-id uint) (count uint))
    ;; Lists a set number of artworks starting from a specific ID
    (ok (map art-id-response 
        (unwrap-panic (as-max-len? 
            (generate-art-list start-id count) 
            u50)))))

;; Add a UI element: Pagination metadata for artwork listing
(define-read-only (get-pagination-info (start-id uint) (count uint))
    ;; Returns pagination metadata for artworks
    {
        total-artworks: (var-get latest-art-id),
        start-id: start-id,
        count: count,
        has-more: (> (var-get latest-art-id) (+ start-id count))
    })

(define-read-only (validate-art-id (art-id uint))
;; Validates if the given artwork ID exists
(ok (and (> art-id u0) (<= art-id (var-get latest-art-id)))))

;; Adds meaningful refactor to improve performance in artwork listing
(define-read-only (list-artworks-optimized (start-id uint) (count uint))
  ;; Retrieves a list of artworks starting from a specific ID with optimized pagination
  (let ((art-list (generate-art-list start-id count)))
    (ok (map art-id-response art-list))))

;; Adds metadata retrieval for UI display
(define-read-only (get-art-metadata (art-id uint))
  ;; Retrieves metadata, including transfer status and owner, for UI elements
  (ok {
    details: (unwrap! (map-get? art-details art-id) err-art-not-found),
    owner: (unwrap! (nft-get-owner? art-token art-id) err-art-not-found),
    transferred: (is-transferred art-id)
  }))

;; Adds utility to count total artworks minted
(define-read-only (get-total-artworks)
  ;; Retrieves the total number of artworks minted
  (ok (var-get latest-art-id)))

(define-read-only (get-pagination-details (start-id uint) (page-size uint))
;; Returns a paginated list of artworks
(ok (as-max-len? 
        (generate-art-list start-id page-size)
        u50)))

(define-read-only (list-transferred-artworks (start-id uint) (count uint))
;; Lists only transferred artworks in the given range
(ok (filter is-transferred 
            (generate-art-list start-id count))))


;; Contract Initialization
(begin
    ;; Initializes the contract by setting the latest artwork ID to 0
    (var-set latest-art-id u0))
