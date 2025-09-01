# 🎓 Gradelink - Exam Result NFTs

> Immutable public test records for students on the Stacks blockchain

## 📋 Overview

Gradelink is a smart contract that creates **immutable NFT records** of student exam results. Each exam result becomes a permanent, verifiable record stored on the blockchain, providing transparency and authenticity for academic achievements.

## ✨ Key Features

- 🏆 **NFT Exam Results** - Each exam result is minted as a unique NFT
- 🔒 **Immutable Records** - Results cannot be altered once recorded
- 👨‍🏫 **Instructor Authorization** - Only authorized instructors can record results  
- 🏫 **Multi-Institution Support** - Support for multiple educational institutions
- 📊 **GPA Calculation** - Automatic GPA calculation from recorded results
- 📚 **Student Profiles** - Comprehensive student record management
- 🎯 **Exam Sessions** - Structured exam management system

## 🚀 Quick Start

### Prerequisites
- Clarinet installed
- Stacks wallet for testing

### Installation
```bash
git clone <repository-url>
cd gradelink
clarinet check
```

### Testing
```bash
clarinet test
```

## 📖 Usage Guide

### 1. 👨‍💼 Setup (Contract Owner)

```clarity
;; Authorize an instructor
(contract-call? .gradelink authorize-instructor 'SP1INSTRUCTOR)

;; Set institution admin
(contract-call? .gradelink set-institution-admin 'SP1ADMIN "University ABC")
```

### 2. 👨‍🎓 Student Registration

```clarity
;; Register a new student
(contract-call? .gradelink register-student 
    "STU001" 
    "John Doe" 
    (some 'SP1STUDENT))
```

### 3. 📝 Create Exam Session

```clarity
;; Create an exam session
(contract-call? .gradelink create-exam-session 
    "MATH101-FINAL" 
    "Mathematics" 
    u100 
    "University ABC")
```

### 4. 📊 Record Exam Results

```clarity
;; Record a single exam result
(contract-call? .gradelink record-exam-result 
    "STU001" 
    "MATH101-FINAL" 
    "A" 
    u95 
    (some "ipfs://metadata-uri"))
```

### 5. 📈 Bulk Record Results

```clarity
;; Record multiple results at once
(contract-call? .gradelink bulk-record-results 
    (list 
        {student-id: "STU001", exam-name: "MATH101-FINAL", grade: "A", score: u95, metadata-uri: none}
        {student-id: "STU002", exam-name: "MATH101-FINAL", grade: "B+", score: u87, metadata-uri: none}
    ))
```

## 🔍 Query Functions

### Get Exam Result
```clarity
(contract-call? .gradelink get-exam-result u1)
```

### Get Student Record
```clarity
(contract-call? .gradelink get-student-record "STU001")
```

### Calculate GPA
```clarity
(contract-call? .gradelink calculate-gpa "STU001" (list u1 u2 u3))
```

### Get Student Exam History
```clarity
(contract-call? .gradelink get-student-exam-history "STU001" u10)
```

## 🏗️ Architecture

### Core Components

- **NFT Implementation** - Each exam result is an NFT with metadata
- **Student Management** - Registration and profile management
- **Exam Sessions** - Structured exam creation and management
- **Authorization System** - Role-based access control
- **Grade Calculation** - Automatic GPA and grade point calculations

### Data Structures

- `exam-results` - Stores NFT exam result data
- `student-records` - Student profile information
- `exam-sessions` - Exam session configurations
- `authorized-instructors` - Instructor permissions
- `institution-admins` - Institution management

## 🔐 Security Features

- **Owner-only Functions** - Critical functions restricted to contract owner
- **Instructor Authorization** - Results can only be recorded by authorized instructors
- **Immutable Records** - Exam results cannot be modified once created
- **Input Validation** - Comprehensive validation of grades and scores

## 📋 Supported Grades

| Grade | Points |
|-------|--------|
| A+    | 100    |
| A     | 95     |
| A-    | 90     |
| B+    | 85     |
| B     | 80     |
| B-    | 75     |
| C+    | 70     |
| C     | 65     |
| C-    | 60     |
| D     | 55     |
| F     | 0      |

## 🎯 Use Cases

- 🏫 **Universities & Colleges** - Permanent academic records
- 🏃‍♂️ **Certification Programs** - Verifiable skill assessments  
- 📜 **Professional Licenses** - Immutable qualification records
- 🏆 **Competition Results** - Transparent scoring systems
- 📚 **Online Education** - Blockchain-verified course completion

## 🛠️ Development

### Error Codes

- `u100` - Owner only operation
- `u101` - Resource not found
- `u102` - Invalid grade format
- `u103` - Resource already exists
- `u104` - Unauthorized access
- `u105` - Invalid student ID
- `u106` - Exam session closed

### Events

The contract emits events when exam results are recorded:

```clarity
{
    event: "exam-result-recorded",
    token-id: u1,
    student-id: "STU001", 
    exam-name: "MATH101-FINAL",
    grade: "A",
    score: u95
}

