
DROP TABLE IF EXISTS BorrowedBooks CASCADE;
DROP TABLE IF EXISTS Books CASCADE;
DROP TABLE IF EXISTS Members CASCADE;
DROP FUNCTION IF EXISTS GetBooksBorrowed;
DROP FUNCTION IF EXISTS PreventBorrowIfNoCopies;
DROP PROCEDURE IF EXISTS BorrowBook;

-- Tables
CREATE TABLE Books (
    BookID INT PRIMARY KEY,
    Title VARCHAR(255) NOT NULL,
    Author VARCHAR(255) NOT NULL,
    CopiesAvailable INT NOT NULL CHECK (CopiesAvailable >= 0),
    TotalCopies INT NOT NULL CHECK (TotalCopies >= CopiesAvailable)
);

CREATE TABLE Members (
    MemberID INT PRIMARY KEY,
    Name VARCHAR(255) NOT NULL,
    Email VARCHAR(255) UNIQUE NOT NULL,
    TotalBooksBorrowed INT DEFAULT 0 CHECK (TotalBooksBorrowed >= 0),
    IsActive BOOLEAN DEFAULT TRUE
);

CREATE TABLE BorrowedBooks (
    BorrowID SERIAL PRIMARY KEY,
    MemberID INT REFERENCES Members(MemberID),
    BookID INT REFERENCES Books(BookID),
    BorrowDate DATE DEFAULT CURRENT_DATE,
    DueDate DATE NOT NULL,
    ReturnDate DATE,
    IsReturned BOOLEAN DEFAULT FALSE
);

-- Indexes
CREATE INDEX idx_books_bookid ON Books(BookID);
CREATE INDEX idx_members_memberid ON Members(MemberID);

-- Function: GetBooksBorrowed
CREATE OR REPLACE FUNCTION GetBooksBorrowed(p_MemberID INT)
RETURNS INT AS $$
DECLARE 
    v_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM BorrowedBooks
    WHERE MemberID = p_MemberID AND IsReturned = FALSE;
    RETURN v_count;
END;
$$ LANGUAGE plpgsql;

-- Trigger Function
CREATE OR REPLACE FUNCTION PreventBorrowIfNoCopies()
RETURNS TRIGGER AS $$
DECLARE
    v_copies INT;
    v_active BOOLEAN;
BEGIN
    SELECT IsActive INTO v_active FROM Members WHERE MemberID = NEW.MemberID;
    IF NOT v_active THEN
        RAISE EXCEPTION 'Member % is inactive', NEW.MemberID;
    END IF;

    SELECT CopiesAvailable INTO v_copies FROM Books WHERE BookID = NEW.BookID;
    IF v_copies <= 0 THEN
        RAISE EXCEPTION 'No copies available for Book %', NEW.BookID;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger
CREATE TRIGGER CheckBeforeBorrow
BEFORE INSERT ON BorrowedBooks
FOR EACH ROW
EXECUTE FUNCTION PreventBorrowIfNoCopies();

-- Stored Procedure: BorrowBook
CREATE OR REPLACE PROCEDURE BorrowBook(
    p_MemberID INT,
    p_BookID INT
) AS $$
DECLARE
    v_due_date DATE := CURRENT_DATE + INTERVAL '14 DAYS';
BEGIN
    -- Insert will trigger PreventBorrowIfNoCopies check
    INSERT INTO BorrowedBooks (MemberID, BookID, DueDate)
    VALUES (p_MemberID, p_BookID, v_due_date);

    UPDATE Books
    SET CopiesAvailable = CopiesAvailable - 1
    WHERE BookID = p_BookID;

    UPDATE Members
    SET TotalBooksBorrowed = TotalBooksBorrowed + 1
    WHERE MemberID = p_MemberID;
END;
$$ LANGUAGE plpgsql;


-- Insert Books
INSERT INTO Books (BookID, Title, Author, CopiesAvailable, TotalCopies) VALUES
(1, 'The Great Gatsby', 'F. Scott Fitzgerald', 3, 5),
(2, '1984', 'George Orwell', 2, 2),
(3, 'To Kill a Mockingbird', 'Harper Lee', 1, 1);

-- Insert Members
INSERT INTO Members (MemberID, Name, Email, IsActive) VALUES
(1, 'Alice Smith', 'alice@example.com', TRUE),
(2, 'Bob Jones', 'bob@example.com', FALSE), -- Inactive member
(3, 'Charlie Brown', 'charlie@example.com', TRUE);

-- Borrowing Attempts
CALL BorrowBook(1, 1); -- Success
CALL BorrowBook(1, 2); -- Success
CALL BorrowBook(3, 3); -- Success (last copy)
CALL BorrowBook(2, 1); -- Should fail (inactive member)
CALL BorrowBook(3, 3); -- Should fail (no copies left)
