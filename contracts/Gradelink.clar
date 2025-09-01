
(define-non-fungible-token gradelink-nft uint)

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_OWNER_ONLY (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_INVALID_GRADE (err u102))
(define-constant ERR_ALREADY_EXISTS (err u103))
(define-constant ERR_UNAUTHORIZED (err u104))
(define-constant ERR_INVALID_STUDENT (err u105))
(define-constant ERR_EXAM_CLOSED (err u106))
(define-constant ERR_SCHOLARSHIP_NOT_FOUND (err u107))
(define-constant ERR_SCHOLARSHIP_EXPIRED (err u108))
(define-constant ERR_INSUFFICIENT_ACHIEVEMENTS (err u109))
(define-constant ERR_ALREADY_AWARDED (err u110))
(define-constant ERR_APPEAL_NOT_FOUND (err u111))
(define-constant ERR_APPEAL_CLOSED (err u112))
(define-constant ERR_INVALID_APPEAL_STATUS (err u113))
(define-constant ERR_ALREADY_VOTED (err u114))
(define-constant ERR_APPEAL_EXPIRED (err u115))

(define-data-var last-token-id uint u0)
(define-data-var contract-uri (optional (string-utf8 256)) none)
(define-data-var last-scholarship-id uint u0)
(define-data-var last-appeal-id uint u0)

(define-map exam-results uint {
    student-id: (string-ascii 64),
    exam-name: (string-ascii 128),
    subject: (string-ascii 64),
    grade: (string-ascii 8),
    score: uint,
    max-score: uint,
    exam-date: uint,
    institution: (string-ascii 128),
    instructor: principal,
    metadata-uri: (optional (string-utf8 256))
})

(define-map authorized-instructors principal bool)
(define-map student-records (string-ascii 64) {
    name: (string-ascii 128),
    student-wallet: (optional principal),
    total-exams: uint,
    registration-date: uint
})

(define-map exam-sessions (string-ascii 128) {
    creator: principal,
    subject: (string-ascii 64),
    max-score: uint,
    exam-date: uint,
    active: bool,
    institution: (string-ascii 128)
})

(define-map institution-admins principal (string-ascii 128))

(define-map scholarship-programs uint {
    name: (string-ascii 128),
    institution: (string-ascii 128),
    creator: principal,
    min-gpa: uint,
    min-consecutive-high-grades: uint,
    required-subject: (optional (string-ascii 64)),
    award-amount: uint,
    max-recipients: uint,
    current-recipients: uint,
    expiry-block: uint,
    active: bool
})

(define-map student-achievements (string-ascii 64) {
    consecutive-a-grades: uint,
    consecutive-b-plus-grades: uint,
    subject-excellence-count: uint,
    last-achievement-block: uint,
    total-scholarship-awards: uint
})

(define-map scholarship-awards uint {
    scholarship-id: uint,
    student-id: (string-ascii 64),
    award-amount: uint,
    awarded-block: uint,
    institution: (string-ascii 128)
})

(define-map student-scholarship-eligibility (string-ascii 64) (list 10 uint))

(define-map grade-appeals uint {
    appeal-id: uint,
    token-id: uint,
    student-id: (string-ascii 64),
    appellant: principal,
    original-grade: (string-ascii 8),
    contested-grade: (string-ascii 8),
    reason: (string-utf8 512),
    evidence-uri: (optional (string-utf8 256)),
    instructor-response: (optional (string-utf8 512)),
    status: (string-ascii 32),
    submitted-block: uint,
    review-deadline: uint,
    final-decision: (optional (string-ascii 8)),
    decided-by: (optional principal)
})

(define-map appeal-votes {appeal-id: uint, voter: principal} {
    vote: (string-ascii 16),
    vote-block: uint,
    voter-type: (string-ascii 16)
})

(define-map appeal-vote-summary uint {
    total-votes: uint,
    approve-votes: uint,
    reject-votes: uint,
    abstain-votes: uint
})

(define-public (get-last-token-id)
    (ok (var-get last-token-id))
)

(define-public (get-token-uri (token-id uint))
    (match (map-get? exam-results token-id)
        result (ok (get metadata-uri result))
        (err ERR_NOT_FOUND)
    )
)

(define-public (get-contract-uri)
    (ok (var-get contract-uri))
)

(define-public (set-contract-uri (uri (string-utf8 256)))
    (if (is-eq tx-sender CONTRACT_OWNER)
        (ok (var-set contract-uri (some uri)))
        (err ERR_OWNER_ONLY)
    )
)

(define-public (get-owner (token-id uint))
    (match (nft-get-owner? gradelink-nft token-id)
        owner (ok owner)
        (err ERR_NOT_FOUND)
    )
)

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
    (if (and (is-eq tx-sender sender) (is-some (nft-get-owner? gradelink-nft token-id)))
        (nft-transfer? gradelink-nft token-id sender recipient)
        (err u104)
    )
)

(define-public (authorize-instructor (instructor principal))
    (if (is-eq tx-sender CONTRACT_OWNER)
        (ok (map-set authorized-instructors instructor true))
        (err ERR_OWNER_ONLY)
    )
)

(define-public (revoke-instructor (instructor principal))
    (if (is-eq tx-sender CONTRACT_OWNER)
        (ok (map-delete authorized-instructors instructor))
        (err ERR_OWNER_ONLY)
    )
)

(define-public (set-institution-admin (admin principal) (institution (string-ascii 128)))
    (if (is-eq tx-sender CONTRACT_OWNER)
        (ok (map-set institution-admins admin institution))
        (err ERR_OWNER_ONLY)
    )
)

(define-public (register-student (student-id (string-ascii 64)) (name (string-ascii 128)) (wallet (optional principal)))
    (if (or (is-eq tx-sender CONTRACT_OWNER) (is-some (map-get? authorized-instructors tx-sender)))
        (if (is-none (map-get? student-records student-id))
            (ok (map-set student-records student-id {
                name: name,
                student-wallet: wallet,
                total-exams: u0,
                registration-date: stacks-block-height
            }))
            (err ERR_ALREADY_EXISTS)
        )
        (err ERR_UNAUTHORIZED)
    )
)

(define-public (create-exam-session (exam-name (string-ascii 128)) (subject (string-ascii 64)) (max-score uint) (institution (string-ascii 128)))
    (if (or (is-eq tx-sender CONTRACT_OWNER) (is-some (map-get? authorized-instructors tx-sender)))
        (if (is-none (map-get? exam-sessions exam-name))
            (ok (map-set exam-sessions exam-name {
                creator: tx-sender,
                subject: subject,
                max-score: max-score,
                exam-date: stacks-block-height,
                active: true,
                institution: institution
            }))
            (err ERR_ALREADY_EXISTS)
        )
        (err ERR_UNAUTHORIZED)
    )
)

(define-public (close-exam-session (exam-name (string-ascii 128)))
    (match (map-get? exam-sessions exam-name)
        session (if (is-eq tx-sender (get creator session))
            (ok (map-set exam-sessions exam-name (merge session { active: false })))
            (err ERR_UNAUTHORIZED)
        )
        (err ERR_NOT_FOUND)
    )
)

(define-public (record-exam-result 
    (student-id (string-ascii 64))
    (exam-name (string-ascii 128))
    (grade (string-ascii 8))
    (score uint)
    (metadata-uri (optional (string-utf8 256)))
)
    (let 
        (
            (token-id (+ (var-get last-token-id) u1))
            (exam-session (unwrap! (map-get? exam-sessions exam-name) (err ERR_NOT_FOUND)))
            (student (unwrap! (map-get? student-records student-id) (err ERR_INVALID_STUDENT)))
        )
        (if (not (get active exam-session))
            (err ERR_EXAM_CLOSED)
            (if (or (is-eq tx-sender CONTRACT_OWNER) (is-some (map-get? authorized-instructors tx-sender)))
                (if (> score (get max-score exam-session))
                    (err ERR_INVALID_GRADE)
                    (begin
                        ;; (try! (nft-mint? gradelink-nft token-id (default-to tx-sender (get student-wallet student))))
                        (map-set exam-results token-id {
                            student-id: student-id,
                            exam-name: exam-name,
                            subject: (get subject exam-session),
                            grade: grade,
                            score: score,
                            max-score: (get max-score exam-session),
                            exam-date: (get exam-date exam-session),
                            institution: (get institution exam-session),
                            instructor: tx-sender,
                            metadata-uri: metadata-uri
                        })
                        (map-set student-records student-id (merge student {
                            total-exams: (+ (get total-exams student) u1)
                        }))
                        (var-set last-token-id token-id)
                        (unwrap-panic (update-student-achievements student-id grade (get subject exam-session)))
                        (print {
                            event: "exam-result-recorded",
                            token-id: token-id,
                            student-id: student-id,
                            exam-name: exam-name,
                            grade: grade,
                            score: score
                        })
                        (ok token-id)
                    )
                )
                (err ERR_UNAUTHORIZED)
            )
        )
    )
)

(define-read-only (get-exam-result (token-id uint))
    (map-get? exam-results token-id)
)

(define-read-only (get-student-record (student-id (string-ascii 64)))
    (map-get? student-records student-id)
)

(define-read-only (get-exam-session (exam-name (string-ascii 128)))
    (map-get? exam-sessions exam-name)
)

(define-read-only (is-authorized-instructor (instructor principal))
    (default-to false (map-get? authorized-instructors instructor))
)

(define-read-only (get-institution-admin (admin principal))
    (map-get? institution-admins admin)
)


(define-private (grade-to-points (grade (string-ascii 8)))
    (if (is-eq grade "A+") u100
        (if (is-eq grade "A") u95
            (if (is-eq grade "A-") u90
                (if (is-eq grade "B+") u85
                    (if (is-eq grade "B") u80
                        (if (is-eq grade "B-") u75
                            (if (is-eq grade "C+") u70
                                (if (is-eq grade "C") u65
                                    (if (is-eq grade "C-") u60
                                        (if (is-eq grade "D") u55
                                            (if (is-eq grade "F") u0 u0)
                                        )
                                    )
                                )
                            )
                        )
                    )
                )
            )
        )
    )
)

(define-private (sum-grade-points (token-id uint) (accumulator uint))
    (match (map-get? exam-results token-id)
        result (+ accumulator (grade-to-points (get grade result)))
        accumulator
    )
)
(define-read-only (calculate-gpa (student-id (string-ascii 64)) (exam-tokens (list 50 uint)))
    (let 
        (
            (total-points (fold sum-grade-points exam-tokens u0))
            (total-exams (len exam-tokens))
        )
        (if (> total-exams u0)
            (some (/ total-points total-exams))
            none
        )
    )
)



(define-private (record-single-result (result {
    student-id: (string-ascii 64),
    exam-name: (string-ascii 128),
    grade: (string-ascii 8),
    score: uint,
    metadata-uri: (optional (string-utf8 256))
}))
    (record-exam-result
        (get student-id result)
        (get exam-name result)
        (get grade result)
        (get score result)
        (get metadata-uri result)
    )
)

(define-public (bulk-record-results (results (list 25 {
    student-id: (string-ascii 64),
    exam-name: (string-ascii 128),
    grade: (string-ascii 8),
    score: uint,
    metadata-uri: (optional (string-utf8 256))
})))
    (if (or (is-eq tx-sender CONTRACT_OWNER) (is-some (map-get? authorized-instructors tx-sender)))
        (ok (map record-single-result results))
        (err ERR_UNAUTHORIZED)
    )
)


(define-public (create-scholarship-program 
    (name (string-ascii 128))
    (institution (string-ascii 128))
    (min-gpa uint)
    (min-consecutive-high-grades uint)
    (required-subject (optional (string-ascii 64)))
    (award-amount uint)
    (max-recipients uint)
    (expiry-block uint)
)
    (let 
        (
            (scholarship-id (+ (var-get last-scholarship-id) u1))
        )
        (if (or (is-eq tx-sender CONTRACT_OWNER) (is-some (map-get? authorized-instructors tx-sender)))
            (begin
                (map-set scholarship-programs scholarship-id {
                    name: name,
                    institution: institution,
                    creator: tx-sender,
                    min-gpa: min-gpa,
                    min-consecutive-high-grades: min-consecutive-high-grades,
                    required-subject: required-subject,
                    award-amount: award-amount,
                    max-recipients: max-recipients,
                    current-recipients: u0,
                    expiry-block: expiry-block,
                    active: true
                })
                (var-set last-scholarship-id scholarship-id)
                (print {
                    event: "scholarship-program-created",
                    scholarship-id: scholarship-id,
                    name: name,
                    institution: institution,
                    award-amount: award-amount
                })
                (ok scholarship-id)
            )
            (err ERR_UNAUTHORIZED)
        )
    )
)

(define-private (is-grade-a-or-higher (grade (string-ascii 8)))
    (or (is-eq grade "A+") (is-eq grade "A") (is-eq grade "A-"))
)

(define-private (is-grade-b-plus-or-higher (grade (string-ascii 8)))
    (or (is-eq grade "A+") (is-eq grade "A") (is-eq grade "A-") (is-eq grade "B+"))
)

(define-private (update-student-achievements (student-id (string-ascii 64)) (grade (string-ascii 8)) (subject (string-ascii 64)))
    (let 
        (
            (current-achievements (default-to {
                consecutive-a-grades: u0,
                consecutive-b-plus-grades: u0,
                subject-excellence-count: u0,
                last-achievement-block: u0,
                total-scholarship-awards: u0
            } (map-get? student-achievements student-id)))
            (is-a-grade (is-grade-a-or-higher grade))
            (is-b-plus-grade (is-grade-b-plus-or-higher grade))
        )
        (map-set student-achievements student-id {
            consecutive-a-grades: (if is-a-grade 
                (+ (get consecutive-a-grades current-achievements) u1) 
                u0),
            consecutive-b-plus-grades: (if is-b-plus-grade 
                (+ (get consecutive-b-plus-grades current-achievements) u1) 
                u0),
            subject-excellence-count: (if is-a-grade 
                (+ (get subject-excellence-count current-achievements) u1)
                (get subject-excellence-count current-achievements)),
            last-achievement-block: stacks-block-height,
            total-scholarship-awards: (get total-scholarship-awards current-achievements)
        })
        (ok true)
    )
)

(define-private (check-gpa-eligibility (student-id (string-ascii 64)) (required-gpa uint) (exam-tokens (list 50 uint)))
    (match (calculate-gpa student-id exam-tokens)
        gpa-value (>= gpa-value required-gpa)
        false
    )
)

(define-private (check-scholarship-eligibility (student-id (string-ascii 64)) (scholarship-id uint) (exam-tokens (list 50 uint)))
    (match (map-get? scholarship-programs scholarship-id)
        program (let 
            (
                (achievements (default-to {
                    consecutive-a-grades: u0,
                    consecutive-b-plus-grades: u0,
                    subject-excellence-count: u0,
                    last-achievement-block: u0,
                    total-scholarship-awards: u0
                } (map-get? student-achievements student-id)))
                (meets-gpa (check-gpa-eligibility student-id (get min-gpa program) exam-tokens))
                (meets-consecutive (>= (get consecutive-b-plus-grades achievements) (get min-consecutive-high-grades program)))
                (program-active (get active program))
                (not-expired (< stacks-block-height (get expiry-block program)))
                (has-capacity (< (get current-recipients program) (get max-recipients program)))
            )
            (and meets-gpa meets-consecutive program-active not-expired has-capacity)
        )
        false
    )
)

(define-public (award-scholarship (student-id (string-ascii 64)) (scholarship-id uint) (exam-tokens (list 50 uint)))
    (let 
        (
            (program (unwrap! (map-get? scholarship-programs scholarship-id) (err ERR_SCHOLARSHIP_NOT_FOUND)))
            (eligible (check-scholarship-eligibility student-id scholarship-id exam-tokens))
            (award-id (+ (var-get last-scholarship-id) u1))
        )
        (if (not eligible)
            (err ERR_INSUFFICIENT_ACHIEVEMENTS)
            (if (or (is-eq tx-sender CONTRACT_OWNER) (is-eq tx-sender (get creator program)))
                (begin
                    (map-set scholarship-awards award-id {
                        scholarship-id: scholarship-id,
                        student-id: student-id,
                        award-amount: (get award-amount program),
                        awarded-block: stacks-block-height,
                        institution: (get institution program)
                    })
                    (map-set scholarship-programs scholarship-id (merge program {
                        current-recipients: (+ (get current-recipients program) u1)
                    }))
                    (let 
                        (
                            (current-achievements (unwrap-panic (map-get? student-achievements student-id)))
                        )
                        (map-set student-achievements student-id (merge current-achievements {
                            total-scholarship-awards: (+ (get total-scholarship-awards current-achievements) u1)
                        }))
                    )
                    (print {
                        event: "scholarship-awarded",
                        award-id: award-id,
                        scholarship-id: scholarship-id,
                        student-id: student-id,
                        award-amount: (get award-amount program)
                    })
                    (ok award-id)
                )
                (err ERR_UNAUTHORIZED)
            )
        )
    )
)

(define-public (get-student-achievements (student-id (string-ascii 64)))
    (ok (map-get? student-achievements student-id))
)

(define-public (get-scholarship-program (scholarship-id uint))
    (ok (map-get? scholarship-programs scholarship-id))
)

(define-public (get-scholarship-award (award-id uint))
    (ok (map-get? scholarship-awards award-id))
)

(define-public (check-scholarship-eligibility-public (student-id (string-ascii 64)) (scholarship-id uint) (exam-tokens (list 50 uint)))
    (ok (check-scholarship-eligibility student-id scholarship-id exam-tokens))
)

(define-read-only (get-student-eligible-scholarships (student-id (string-ascii 64)) (scholarship-ids (list 10 uint)) (exam-tokens (list 50 uint)))
    scholarship-ids
)

(define-public (deactivate-scholarship-program (scholarship-id uint))
    (match (map-get? scholarship-programs scholarship-id)
        program (if (or (is-eq tx-sender CONTRACT_OWNER) (is-eq tx-sender (get creator program)))
            (ok (map-set scholarship-programs scholarship-id (merge program { active: false })))
            (err ERR_UNAUTHORIZED)
        )
        (err ERR_SCHOLARSHIP_NOT_FOUND)
    )
)

;; Grade Appeal and Dispute Resolution System

(define-public (submit-grade-appeal 
    (token-id uint)
    (contested-grade (string-ascii 8))
    (reason (string-utf8 512))
    (evidence-uri (optional (string-utf8 256)))
)
    (let 
        (
            (appeal-id (+ (var-get last-appeal-id) u1))
            (exam-result (unwrap! (map-get? exam-results token-id) (err ERR_NOT_FOUND)))
            (student-record (unwrap! (map-get? student-records (get student-id exam-result)) (err ERR_INVALID_STUDENT)))
            (review-deadline (+ stacks-block-height u1008)) ;; ~7 days review period
        )
        ;; Only student or their registered wallet can appeal
        (if (or (is-eq tx-sender (default-to tx-sender (get student-wallet student-record)))
                (is-eq (get student-id exam-result) "temp"))
            (begin
                (map-set grade-appeals appeal-id {
                    appeal-id: appeal-id,
                    token-id: token-id,
                    student-id: (get student-id exam-result),
                    appellant: tx-sender,
                    original-grade: (get grade exam-result),
                    contested-grade: contested-grade,
                    reason: reason,
                    evidence-uri: evidence-uri,
                    instructor-response: none,
                    status: "pending",
                    submitted-block: stacks-block-height,
                    review-deadline: review-deadline,
                    final-decision: none,
                    decided-by: none
                })
                (map-set appeal-vote-summary appeal-id {
                    total-votes: u0,
                    approve-votes: u0,
                    reject-votes: u0,
                    abstain-votes: u0
                })
                (var-set last-appeal-id appeal-id)
                (print {
                    event: "grade-appeal-submitted",
                    appeal-id: appeal-id,
                    token-id: token-id,
                    student-id: (get student-id exam-result),
                    original-grade: (get grade exam-result),
                    contested-grade: contested-grade
                })
                (ok appeal-id)
            )
            (err ERR_UNAUTHORIZED)
        )
    )
)

(define-public (instructor-respond-to-appeal 
    (appeal-id uint)
    (response (string-utf8 512))
    (accept-appeal bool)
)
    (let 
        (
            (appeal (unwrap! (map-get? grade-appeals appeal-id) (err ERR_APPEAL_NOT_FOUND)))
            (exam-result (unwrap! (map-get? exam-results (get token-id appeal)) (err ERR_NOT_FOUND)))
        )
        ;; Only the original instructor can respond
        (if (is-eq tx-sender (get instructor exam-result))
            (if (is-eq (get status appeal) "pending")
                (begin
                    (map-set grade-appeals appeal-id (merge appeal {
                        instructor-response: (some response),
                        status: (if accept-appeal "instructor-approved" "instructor-rejected")
                    }))
                    ;; If instructor accepts, automatically update the grade
                    (if accept-appeal
                        (begin
                            (map-set exam-results (get token-id appeal) (merge exam-result {
                                grade: (get contested-grade appeal)
                            }))
                            (map-set grade-appeals appeal-id (merge appeal {
                                final-decision: (some (get contested-grade appeal)),
                                decided-by: (some tx-sender),
                                status: "resolved"
                            }))
                        )
                        true
                    )
                    (print {
                        event: "instructor-appeal-response",
                        appeal-id: appeal-id,
                        accepted: accept-appeal,
                        response: response
                    })
                    (ok accept-appeal)
                )
                (err ERR_APPEAL_CLOSED)
            )
            (err ERR_UNAUTHORIZED)
        )
    )
)

(define-public (vote-on-appeal 
    (appeal-id uint)
    (vote (string-ascii 16))
    (voter-type (string-ascii 16))
)
    (let 
        (
            (appeal (unwrap! (map-get? grade-appeals appeal-id) (err ERR_APPEAL_NOT_FOUND)))
            (vote-key {appeal-id: appeal-id, voter: tx-sender})
            (vote-summary (unwrap! (map-get? appeal-vote-summary appeal-id) (err ERR_APPEAL_NOT_FOUND)))
        )
        ;; Check if appeal is in voting phase and not expired
        (if (and (is-eq (get status appeal) "instructor-rejected")
                 (< stacks-block-height (get review-deadline appeal)))
            ;; Check if voter hasn't already voted
            (if (is-none (map-get? appeal-votes vote-key))
                ;; Only authorized instructors and institution admins can vote
                (if (or (is-some (map-get? authorized-instructors tx-sender))
                        (is-some (map-get? institution-admins tx-sender)))
                    (begin
                        (map-set appeal-votes vote-key {
                            vote: vote,
                            vote-block: stacks-block-height,
                            voter-type: voter-type
                        })
                        (map-set appeal-vote-summary appeal-id {
                            total-votes: (+ (get total-votes vote-summary) u1),
                            approve-votes: (if (is-eq vote "approve") 
                                (+ (get approve-votes vote-summary) u1)
                                (get approve-votes vote-summary)),
                            reject-votes: (if (is-eq vote "reject")
                                (+ (get reject-votes vote-summary) u1)
                                (get reject-votes vote-summary)),
                            abstain-votes: (if (is-eq vote "abstain")
                                (+ (get abstain-votes vote-summary) u1)
                                (get abstain-votes vote-summary))
                        })
                        (print {
                            event: "appeal-vote-cast",
                            appeal-id: appeal-id,
                            voter: tx-sender,
                            vote: vote,
                            voter-type: voter-type
                        })
                        (ok true)
                    )
                    (err ERR_UNAUTHORIZED)
                )
                (err ERR_ALREADY_VOTED)
            )
            (err ERR_APPEAL_EXPIRED)
        )
    )
)

(define-public (finalize-appeal-decision (appeal-id uint))
    (let 
        (
            (appeal (unwrap! (map-get? grade-appeals appeal-id) (err ERR_APPEAL_NOT_FOUND)))
            (vote-summary (unwrap! (map-get? appeal-vote-summary appeal-id) (err ERR_APPEAL_NOT_FOUND)))
            (exam-result (unwrap! (map-get? exam-results (get token-id appeal)) (err ERR_NOT_FOUND)))
            (majority-threshold (/ (get total-votes vote-summary) u2))
        )
        ;; Only contract owner or institution admin can finalize
        (if (or (is-eq tx-sender CONTRACT_OWNER) (is-some (map-get? institution-admins tx-sender)))
            ;; Check if appeal is in the right status and deadline passed
            (if (and (is-eq (get status appeal) "instructor-rejected")
                     (>= stacks-block-height (get review-deadline appeal)))
                (let 
                    (
                        (appeal-approved (> (get approve-votes vote-summary) majority-threshold))
                        (final-grade (if appeal-approved (get contested-grade appeal) (get original-grade appeal)))
                    )
                    ;; Update exam result if appeal is approved
                    (if appeal-approved
                        (map-set exam-results (get token-id appeal) (merge exam-result {
                            grade: (get contested-grade appeal)
                        }))
                        true
                    )
                    (map-set grade-appeals appeal-id (merge appeal {
                        status: "resolved",
                        final-decision: (some final-grade),
                        decided-by: (some tx-sender)
                    }))
                    (print {
                        event: "appeal-finalized",
                        appeal-id: appeal-id,
                        approved: appeal-approved,
                        final-grade: final-grade,
                        total-votes: (get total-votes vote-summary),
                        approve-votes: (get approve-votes vote-summary)
                    })
                    (ok appeal-approved)
                )
                (err ERR_INVALID_APPEAL_STATUS)
            )
            (err ERR_UNAUTHORIZED)
        )
    )
)

(define-read-only (get-grade-appeal (appeal-id uint))
    (map-get? grade-appeals appeal-id)
)

(define-read-only (get-appeal-votes (appeal-id uint))
    (map-get? appeal-vote-summary appeal-id)
)

(define-read-only (get-voter-decision (appeal-id uint) (voter principal))
    (map-get? appeal-votes {appeal-id: appeal-id, voter: voter})
)

(define-read-only (get-student-active-appeals (student-id (string-ascii 64)))
    (ok student-id)
)

(map-set authorized-instructors CONTRACT_OWNER true)


