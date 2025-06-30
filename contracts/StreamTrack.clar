;; StreamTrack - Music artist streaming revenue tracking and royalty distribution platform
(define-data-var music-producer principal tx-sender)
(define-data-var total-streaming-credits uint u0)
(define-data-var royalty-distribution-factor uint u45) ;; distribution factor per stream engagement
(define-data-var last-royalty-period uint u0)

(define-map artist-streams principal uint)
(define-map music-genres principal (string-utf8 64))
(define-map promoted-genres (string-utf8 64) bool)

;; Error codes
(define-constant err-unauthorized-producer (err u2600))
(define-constant err-producer-already-established (err u2601))
(define-constant err-invalid-credit-count (err u2602))
(define-constant err-no-royalty-distribution (err u2603))
(define-constant err-no-streaming-activity (err u2604))
(define-constant err-invalid-music-genre (err u2605))
(define-constant err-genre-not-promoted (err u2606))

;; Verify producer authorization
(define-private (is-music-producer (caller principal))
  (begin
    (asserts! (is-eq caller (var-get music-producer)) err-unauthorized-producer)
    (ok true)))

;; Initialize music streaming revenue tracking platform
(define-public (establish-stream-tracker (producer principal))
  (begin
    (asserts! (is-none (map-get? artist-streams producer)) err-producer-already-established)
    (var-set music-producer producer)
    (ok "StreamTrack music streaming revenue platform established")))

;; Promote music genre for streaming monetization
(define-public (promote-music-genre (genre (string-utf8 64)))
  (begin
    (try! (is-music-producer tx-sender))
    (asserts! (> (len genre) u0) err-invalid-music-genre)
    (map-set promoted-genres genre true)
    (ok "Music genre promoted for streaming monetization")))

;; Register music streaming activity
(define-public (register-streaming-activity (credits uint) (music-genre (string-utf8 64)))
  (begin
    (asserts! (> credits u0) err-invalid-credit-count)
    (asserts! (default-to false (map-get? promoted-genres music-genre)) err-genre-not-promoted)
    
    (let ((current-streams (default-to u0 (map-get? artist-streams tx-sender))))
      (map-set artist-streams tx-sender (+ current-streams credits))
      (map-set music-genres tx-sender music-genre)
      (var-set total-streaming-credits (+ (var-get total-streaming-credits) credits))
      (ok (+ current-streams credits)))))

;; Process streaming royalty distribution
(define-public (process-royalty-distribution)
  (begin
    (try! (is-music-producer tx-sender))
    (let ((current-period (+ (var-get last-royalty-period) u1))
          (total-credits (var-get total-streaming-credits)))
      (asserts! (> total-credits (var-get last-royalty-period)) err-no-royalty-distribution)
      
      (let ((royalty-pool (* (var-get royalty-distribution-factor) total-credits)))
        (var-set last-royalty-period current-period)
        (ok royalty-pool)))))

;; Claim music streaming revenue and royalties
(define-public (claim-streaming-revenue)
  (begin
    (let ((artist-streaming-credits (default-to u0 (map-get? artist-streams tx-sender))))
      (asserts! (> artist-streaming-credits u0) err-no-streaming-activity)
      
      (let ((total-credits (var-get total-streaming-credits))
            (base-royalty-rewards (* (var-get royalty-distribution-factor) artist-streaming-credits))
            (streaming-ratio (/ (* artist-streaming-credits u100000) total-credits)))
        
        (let ((final-streaming-revenue (/ (* streaming-ratio base-royalty-rewards) u100000)))
          (map-delete artist-streams tx-sender)
          (map-delete music-genres tx-sender)
          (var-set total-streaming-credits (- (var-get total-streaming-credits) artist-streaming-credits))
          (ok (+ artist-streaming-credits final-streaming-revenue)))))))

;; Read-only functions
(define-read-only (get-artist-streams (artist principal))
  (default-to u0 (map-get? artist-streams artist)))

(define-read-only (get-music-genre (artist principal))
  (map-get? music-genres artist))

(define-read-only (get-total-streaming-credits)
  (var-get total-streaming-credits))

(define-read-only (is-genre-promoted (genre (string-utf8 64)))
  (default-to false (map-get? promoted-genres genre)))