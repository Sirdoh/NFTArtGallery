;; Art Management Smart Contract
;; Manages artwork NFTs, allowing minting, transferring, and querying artwork details.

;; Constants
(define-constant gallery-admin tx-sender) ;; Gallery admin address (only they can mint artwork)
(define-constant err-not-admin (err u200)) ;; Error if caller is not admin
(define-constant err-not-art-owner (err u201)) ;; Error if sender is not artwork owner
(define-constant err-invalid-art-details (err u204)) ;; Error for invalid artwork details

;; Data Variables
(define-non-fungible-token art-token uint) ;; NFT for artwork
(define-data-var latest-art-id uint u0) ;; Latest artwork ID (starts at 0)
(define-map art-details uint (string-ascii 512)) ;; Maps artwork ID to details

;; Private Functions

;; Validates artwork details length (1-512 characters)
(define-private (is-valid-details (details (string-ascii 512)))
    (and (>= (len details) u1) (<= (len details) u512)))

;; Mints a new artwork NFT, stores its details, and updates latest art ID
(define-private (mint-art (details-data (string-ascii 512)))
    (let ((art-id (+ (var-get latest-art-id) u1))) ;; Increment ID
        (asserts! (is-valid-details details-data) err-invalid-art-details) ;; Validate details
        (try! (nft-mint? art-token art-id tx-sender)) ;; Mint NFT
        (map-set art-details art-id details-data) ;; Store details
        (var-set latest-art-id art-id) ;; Update latest art ID
        (ok art-id))) ;; Return artwork ID

;; Public Functions

;; Allows admin to add new artwork
(define-public (add-artwork (details-data (string-ascii 512)))
    (begin
        (asserts! (is-eq tx-sender gallery-admin) err-not-admin) ;; Ensure admin
        (asserts! (is-valid-details details-data) err-invalid-art-details) ;; Validate details
        (mint-art details-data))) ;; Mint artwork

;; Transfers artwork to a new owner
(define-public (transfer-art (art-id uint) (recipient principal))
    (let ((current-owner (unwrap! (nft-get-owner? art-token art-id) err-not-art-owner))) ;; Get current owner
        (asserts! (is-eq current-owner tx-sender) err-not-art-owner) ;; Ensure sender is owner
        (try! (nft-transfer? art-token art-id tx-sender recipient)) ;; Transfer NFT
        (ok true))) ;; Return success

;; Read-Only Functions

;; Retrieves artwork details by ID
(define-read-only (get-art-details (art-id uint))
    (ok (map-get? art-details art-id)))

;; Retrieves artwork owner by ID
(define-read-only (get-art-owner (art-id uint))
    (ok (nft-get-owner? art-token art-id)))

;; Retrieves the latest artwork ID
(define-read-only (get-latest-art-id)
    (ok (var-get latest-art-id)))

;; Contract Initialization
(begin
    (var-set latest-art-id u0)) ;; Initialize latest artwork ID to 0
