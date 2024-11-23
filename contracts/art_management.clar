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

(define-private (mint-art-batch (details (string-ascii 512)) (previous-results (list 50 uint)))
    ;; Helper function to mint a batch of artworks
    (match (mint-art details)
        success (unwrap-panic (as-max-len? (append previous-results success) u50)) ;; Ensure no overflow
        error previous-results)) ;; Return previous results in case of error

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

;; Contract Initialization
(begin
    ;; Initializes the contract by setting the latest artwork ID to 0
    (var-set latest-art-id u0))
