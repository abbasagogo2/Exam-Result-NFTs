
(define-non-fungible-token gradelink-nft uint)

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_OWNER_ONLY (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_INVALID_GRADE (err u102))
(define-constant ERR_ALREADY_EXISTS (err u103))
(define-constant ERR_UNAUTHORIZED (err u104))
(define-constant ERR_INVALID_STUDENT (err u105))
(define-constant ERR_EXAM_CLOSED (err u106))

(define-data-var last-token-id uint u0)
(define-data-var contract-uri (optional (string-utf8 256)) none)

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


(map-set authorized-instructors CONTRACT_OWNER true)
