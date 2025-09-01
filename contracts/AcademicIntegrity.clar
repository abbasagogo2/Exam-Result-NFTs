;; Academic Integrity Verification System
;; Provides cryptographic proof of original work and prevents academic misconduct

;; Error constants
(define-constant ERR_NOT_AUTHORIZED (err u200))
(define-constant ERR_SUBMISSION_NOT_FOUND (err u201))
(define-constant ERR_SUBMISSION_DEADLINE_PASSED (err u202))
(define-constant ERR_ALREADY_SUBMITTED (err u203))
(define-constant ERR_INVALID_WORK_HASH (err u204))
(define-constant ERR_COLLABORATION_NOT_ALLOWED (err u205))
(define-constant ERR_INTEGRITY_VIOLATION (err u206))
(define-constant ERR_INSUFFICIENT_REPUTATION (err u207))
(define-constant ERR_ASSIGNMENT_NOT_FOUND (err u208))
(define-constant ERR_VIOLATION_NOT_FOUND (err u209))
(define-constant ERR_REVIEWER_NOT_QUALIFIED (err u210))

;; Data variables
(define-data-var last-assignment-id uint u0)
(define-data-var last-submission-id uint u0)
(define-data-var last-violation-id uint u0)
(define-data-var contract-admin principal tx-sender)

;; Assignment management - defines academic work requirements
(define-map assignments uint {
    assignment-name: (string-ascii 128),
    course-id: (string-ascii 64),
    instructor: principal,
    submission-deadline: uint,
    max-submission-size: uint,
    allows-collaboration: bool,
    max-collaborators: uint,
    requires-proctoring: bool,
    integrity-threshold: uint,
    created-block: uint,
    active: bool
})

;; Work submission tracking with cryptographic verification
(define-map work-submissions uint {
    submission-id: uint,
    assignment-id: uint,
    student-id: (string-ascii 64),
    submitter: principal,
    work-hash: (buff 32),
    submission-timestamp: uint,
    file-size: uint,
    collaboration-authorized: bool,
    collaborators: (list 10 (string-ascii 64)),
    proctoring-verified: bool,
    proctor: (optional principal),
    integrity-score: uint,
    plagiarism-checked: bool,
    original-content-percentage: uint,
    verified: bool
})

;; Student academic integrity reputation system
(define-map student-integrity-scores (string-ascii 64) {
    total-submissions: uint,
    verified-submissions: uint,
    collaboration-count: uint,
    violation-count: uint,
    reputation-score: uint,
    last-violation-block: uint,
    probation-status: bool,
    probation-end-block: uint
})

;; Plagiarism and violation detection
(define-map integrity-violations uint {
    violation-id: uint,
    assignment-id: uint,
    accused-student: (string-ascii 64),
    violation-type: (string-ascii 32),
    evidence-hash: (buff 32),
    reported-by: principal,
    reported-block: uint,
    similarity-percentage: uint,
    related-submission-id: (optional uint),
    review-status: (string-ascii 16),
    penalty-applied: bool,
    penalty-type: (optional (string-ascii 64)),
    resolved-block: (optional uint),
    resolved-by: (optional principal)
})

;; Collaboration tracking for group work
(define-map collaboration-groups {assignment-id: uint, group-id: uint} {
    group-members: (list 10 (string-ascii 64)),
    group-leader: (string-ascii 64),
    approved-by: principal,
    created-block: uint,
    collaboration-hash: (buff 32),
    submission-count: uint,
    active: bool
})

;; Proctoring verification for high-stakes exams
(define-map proctoring-sessions uint {
    assignment-id: uint,
    student-id: (string-ascii 64),
    proctor: principal,
    session-start: uint,
    session-end: uint,
    verification-hash: (buff 32),
    integrity-verified: bool,
    anomalies-detected: uint,
    session-recording-hash: (optional (buff 32))
})

;; Academic integrity review board
(define-map authorized-reviewers principal {
    reviewer-type: (string-ascii 16),
    institution: (string-ascii 128),
    reviews-completed: uint,
    accuracy-score: uint,
    active: bool
})

;; Public functions for assignment management
(define-public (create-assignment 
    (name (string-ascii 128))
    (course-id (string-ascii 64))
    (deadline uint)
    (max-size uint)
    (allows-collaboration bool)
    (max-collaborators uint)
    (requires-proctoring bool)
    (integrity-threshold uint)
)
    (let 
        (
            (assignment-id (+ (var-get last-assignment-id) u1))
        )
        (if (or (is-eq tx-sender (var-get contract-admin)) 
                (is-some (map-get? authorized-reviewers tx-sender)))
            (begin
                (map-set assignments assignment-id {
                    assignment-name: name,
                    course-id: course-id,
                    instructor: tx-sender,
                    submission-deadline: deadline,
                    max-submission-size: max-size,
                    allows-collaboration: allows-collaboration,
                    max-collaborators: max-collaborators,
                    requires-proctoring: requires-proctoring,
                    integrity-threshold: integrity-threshold,
                    created-block: stacks-block-height,
                    active: true
                })
                (var-set last-assignment-id assignment-id)
                (print {
                    event: "assignment-created",
                    assignment-id: assignment-id,
                    name: name,
                    course-id: course-id,
                    deadline: deadline
                })
                (ok assignment-id)
            )
            ERR_NOT_AUTHORIZED
        )
    )
)

;; Submit academic work with integrity verification
(define-public (submit-work
    (assignment-id uint)
    (student-id (string-ascii 64))
    (work-hash (buff 32))
    (file-size uint)
    (collaborators (list 10 (string-ascii 64)))
    (proctoring-hash (optional (buff 32)))
)
    (let 
        (
            (submission-id (+ (var-get last-submission-id) u1))
            (assignment (unwrap! (map-get? assignments assignment-id) ERR_ASSIGNMENT_NOT_FOUND))
            (current-score (default-to {
                total-submissions: u0,
                verified-submissions: u0,
                collaboration-count: u0,
                violation-count: u0,
                reputation-score: u100,
                last-violation-block: u0,
                probation-status: false,
                probation-end-block: u0
            } (map-get? student-integrity-scores student-id)))
        )
        ;; Check submission deadline
        (if (> stacks-block-height (get submission-deadline assignment))
            ERR_SUBMISSION_DEADLINE_PASSED
            ;; Check if student is on probation
            (if (and (get probation-status current-score)
                     (< stacks-block-height (get probation-end-block current-score)))
                ERR_INSUFFICIENT_REPUTATION
                ;; Verify collaboration rules
                (if (and (not (get allows-collaboration assignment))
                         (> (len collaborators) u0))
                    ERR_COLLABORATION_NOT_ALLOWED
                    (begin
                        (map-set work-submissions submission-id {
                            submission-id: submission-id,
                            assignment-id: assignment-id,
                            student-id: student-id,
                            submitter: tx-sender,
                            work-hash: work-hash,
                            submission-timestamp: stacks-block-height,
                            file-size: file-size,
                            collaboration-authorized: (get allows-collaboration assignment),
                            collaborators: collaborators,
                            proctoring-verified: (is-some proctoring-hash),
                            proctor: none,
                            integrity-score: u0,
                            plagiarism-checked: false,
                            original-content-percentage: u0,
                            verified: false
                        })
                        ;; Update student integrity tracking
                        (map-set student-integrity-scores student-id (merge current-score {
                            total-submissions: (+ (get total-submissions current-score) u1),
                            collaboration-count: (if (> (len collaborators) u0)
                                (+ (get collaboration-count current-score) u1)
                                (get collaboration-count current-score))
                        }))
                        (var-set last-submission-id submission-id)
                        (print {
                            event: "work-submitted",
                            submission-id: submission-id,
                            assignment-id: assignment-id,
                            student-id: student-id,
                            work-hash: work-hash,
                            collaborators: (len collaborators)
                        })
                        (ok submission-id)
                    )
                )
            )
        )
    )
)

;; Verify plagiarism check results
(define-public (verify-originality
    (submission-id uint)
    (originality-percentage uint)
    (similarity-sources (list 5 (buff 32)))
)
    (let 
        (
            (submission (unwrap! (map-get? work-submissions submission-id) ERR_SUBMISSION_NOT_FOUND))
            (assignment (unwrap! (map-get? assignments (get assignment-id submission)) ERR_ASSIGNMENT_NOT_FOUND))
        )
        ;; Only authorized reviewers can verify originality
        (if (or (is-eq tx-sender (get instructor assignment))
                (is-some (map-get? authorized-reviewers tx-sender)))
            (let 
                (
                    (passes-threshold (>= originality-percentage (get integrity-threshold assignment)))
                    (integrity-score (if passes-threshold u100 (/ (* originality-percentage u100) (get integrity-threshold assignment))))
                )
                (map-set work-submissions submission-id (merge submission {
                    plagiarism-checked: true,
                    original-content-percentage: originality-percentage,
                    integrity-score: integrity-score,
                    verified: passes-threshold
                }))
                ;; Update student reputation if verified
                (if passes-threshold
                    (let 
                        (
                            (current-score (unwrap-panic (map-get? student-integrity-scores (get student-id submission))))
                        )
                        (map-set student-integrity-scores (get student-id submission) (merge current-score {
                            verified-submissions: (+ (get verified-submissions current-score) u1),
                            reputation-score: (if (<= (+ (get reputation-score current-score) u1) u100) (+ (get reputation-score current-score) u1) u100)
                        }))
                    )
                    ;; Flag potential integrity violation if below threshold
                    (begin
                        (if (< originality-percentage (get integrity-threshold assignment))
                            (unwrap-panic (report-integrity-violation 
                                (get assignment-id submission)
                                (get student-id submission)
                                "plagiarism"
                                0x00000000000000000000000000000000000000000000000000000000000000
                                originality-percentage
                                (some submission-id)
                            ))
                            u0
                        )
                        true
                    )
                )
                (print {
                    event: "originality-verified",
                    submission-id: submission-id,
                    originality-percentage: originality-percentage,
                    passes-threshold: passes-threshold,
                    integrity-score: integrity-score
                })
                (ok passes-threshold)
            )
            ERR_NOT_AUTHORIZED
        )
    )
)

;; Report integrity violations with evidence
(define-public (report-integrity-violation
    (assignment-id uint)
    (accused-student (string-ascii 64))
    (violation-type (string-ascii 32))
    (evidence-hash (buff 32))
    (similarity-percentage uint)
    (related-submission (optional uint))
)
    (let 
        (
            (violation-id (+ (var-get last-violation-id) u1))
        )
        ;; Only authorized reviewers can report violations
        (if (or (is-eq tx-sender (var-get contract-admin))
                (is-some (map-get? authorized-reviewers tx-sender)))
            (begin
                (map-set integrity-violations violation-id {
                    violation-id: violation-id,
                    assignment-id: assignment-id,
                    accused-student: accused-student,
                    violation-type: violation-type,
                    evidence-hash: evidence-hash,
                    reported-by: tx-sender,
                    reported-block: stacks-block-height,
                    similarity-percentage: similarity-percentage,
                    related-submission-id: related-submission,
                    review-status: "pending",
                    penalty-applied: false,
                    penalty-type: none,
                    resolved-block: none,
                    resolved-by: none
                })
                (var-set last-violation-id violation-id)
                (print {
                    event: "integrity-violation-reported",
                    violation-id: violation-id,
                    accused-student: accused-student,
                    violation-type: violation-type,
                    similarity-percentage: similarity-percentage
                })
                (ok violation-id)
            )
            ERR_NOT_AUTHORIZED
        )
    )
)

;; Resolve integrity violations with penalties
(define-public (resolve-violation
    (violation-id uint)
    (penalty-type (string-ascii 64))
    (probation-blocks uint)
)
    (let 
        (
            (violation (unwrap! (map-get? integrity-violations violation-id) ERR_VIOLATION_NOT_FOUND))
            (current-score (default-to {
                total-submissions: u0,
                verified-submissions: u0,
                collaboration-count: u0,
                violation-count: u0,
                reputation-score: u100,
                last-violation-block: u0,
                probation-status: false,
                probation-end-block: u0
            } (map-get? student-integrity-scores (get accused-student violation))))
        )
        ;; Only contract admin or authorized reviewers can resolve
        (if (or (is-eq tx-sender (var-get contract-admin))
                (is-some (map-get? authorized-reviewers tx-sender)))
            (begin
                ;; Apply penalty to student record
                (map-set student-integrity-scores (get accused-student violation) (merge current-score {
                    violation-count: (+ (get violation-count current-score) u1),
                    reputation-score: (if (> (get reputation-score current-score) u10)
                        (- (get reputation-score current-score) u10)
                        u0),
                    last-violation-block: stacks-block-height,
                    probation-status: (> probation-blocks u0),
                    probation-end-block: (+ stacks-block-height probation-blocks)
                }))
                ;; Update violation record
                (map-set integrity-violations violation-id (merge violation {
                    review-status: "resolved",
                    penalty-applied: true,
                    penalty-type: (some penalty-type),
                    resolved-block: (some stacks-block-height),
                    resolved-by: (some tx-sender)
                }))
                (print {
                    event: "violation-resolved",
                    violation-id: violation-id,
                    accused-student: (get accused-student violation),
                    penalty-type: penalty-type,
                    probation-blocks: probation-blocks
                })
                (ok true)
            )
            ERR_NOT_AUTHORIZED
        )
    )
)

;; Authorize collaboration groups for specific assignments
(define-public (authorize-collaboration
    (assignment-id uint)
    (group-id uint)
    (members (list 10 (string-ascii 64)))
    (group-leader (string-ascii 64))
)
    (let 
        (
            (assignment (unwrap! (map-get? assignments assignment-id) ERR_ASSIGNMENT_NOT_FOUND))
            (group-key {assignment-id: assignment-id, group-id: group-id})
            (collaboration-hash (keccak256 (unwrap-panic (to-consensus-buff? members))))
        )
        ;; Only instructor can authorize collaboration
        (if (or (is-eq tx-sender (get instructor assignment))
                (is-eq tx-sender (var-get contract-admin)))
            (if (get allows-collaboration assignment)
                (begin
                    (map-set collaboration-groups group-key {
                        group-members: members,
                        group-leader: group-leader,
                        approved-by: tx-sender,
                        created-block: stacks-block-height,
                        collaboration-hash: collaboration-hash,
                        submission-count: u0,
                        active: true
                    })
                    (print {
                        event: "collaboration-authorized",
                        assignment-id: assignment-id,
                        group-id: group-id,
                        members: (len members),
                        group-leader: group-leader
                    })
                    (ok group-id)
                )
                ERR_COLLABORATION_NOT_ALLOWED
            )
            ERR_NOT_AUTHORIZED
        )
    )
)

;; Proctoring verification for high-stakes examinations
(define-public (verify-proctoring
    (assignment-id uint)
    (student-id (string-ascii 64))
    (session-start uint)
    (session-end uint)
    (verification-hash (buff 32))
    (anomalies uint)
)
    (let 
        (
            (assignment (unwrap! (map-get? assignments assignment-id) ERR_ASSIGNMENT_NOT_FOUND))
        )
        ;; Only authorized proctors can verify sessions
        (if (is-some (map-get? authorized-reviewers tx-sender))
            (begin
                (map-set proctoring-sessions assignment-id {
                    assignment-id: assignment-id,
                    student-id: student-id,
                    proctor: tx-sender,
                    session-start: session-start,
                    session-end: session-end,
                    verification-hash: verification-hash,
                    integrity-verified: (is-eq anomalies u0),
                    anomalies-detected: anomalies,
                    session-recording-hash: none
                })
                (print {
                    event: "proctoring-verified",
                    assignment-id: assignment-id,
                    student-id: student-id,
                    integrity-verified: (is-eq anomalies u0),
                    anomalies-detected: anomalies
                })
                (ok (is-eq anomalies u0))
            )
            ERR_NOT_AUTHORIZED
        )
    )
)

;; Administrative functions
(define-public (authorize-reviewer (reviewer principal) (reviewer-type (string-ascii 16)) (institution (string-ascii 128)))
    (if (is-eq tx-sender (var-get contract-admin))
        (ok (map-set authorized-reviewers reviewer {
            reviewer-type: reviewer-type,
            institution: institution,
            reviews-completed: u0,
            accuracy-score: u100,
            active: true
        }))
        ERR_NOT_AUTHORIZED
    )
)

;; Read-only functions for data access
(define-read-only (get-assignment (assignment-id uint))
    (map-get? assignments assignment-id)
)

(define-read-only (get-submission (submission-id uint))
    (map-get? work-submissions submission-id)
)

(define-read-only (get-student-integrity-score (student-id (string-ascii 64)))
    (map-get? student-integrity-scores student-id)
)

(define-read-only (get-violation (violation-id uint))
    (map-get? integrity-violations violation-id)
)

(define-read-only (get-collaboration-group (assignment-id uint) (group-id uint))
    (map-get? collaboration-groups {assignment-id: assignment-id, group-id: group-id})
)

(define-read-only (get-proctoring-session (assignment-id uint))
    (map-get? proctoring-sessions assignment-id)
)

(define-read-only (is-reviewer-authorized (reviewer principal))
    (is-some (map-get? authorized-reviewers reviewer))
)

;; Calculate student integrity reputation
(define-read-only (calculate-integrity-reputation (student-id (string-ascii 64)))
    (match (map-get? student-integrity-scores student-id)
        score (let 
            (
                (base-score (get reputation-score score))
                (verification-rate (if (> (get total-submissions score) u0)
                    (/ (* (get verified-submissions score) u100) (get total-submissions score))
                    u100))
                (violation-penalty (* (get violation-count score) u5))
                (final-score (if (> (+ base-score verification-rate) violation-penalty)
                    (- (+ base-score verification-rate) violation-penalty)
                    u0))
            )
            (if (<= final-score u100) final-score u100)
        )
        u100
    )
)

;; Initialize contract with admin
(map-set authorized-reviewers (var-get contract-admin) {
    reviewer-type: "admin",
    institution: "System",
    reviews-completed: u0,
    accuracy-score: u100,
    active: true
})
