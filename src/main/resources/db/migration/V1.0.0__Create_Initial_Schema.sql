-- use category to organize the books
CREATE TABLE categories (
    category_id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT
);

-- add additional columns to better manage the book, also help the user to understand the book easier
CREATE TABLE books (
    book_id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    isbn VARCHAR(13) UNIQUE,
    author VARCHAR(100) NOT NULL,
    publisher VARCHAR(100),
    publication_year INT,
    category_id INT,
    description TEXT,
    FOREIGN KEY (category_id) REFERENCES categories(category_id)
);

-- add more details to manage the borrower
CREATE TABLE borrowers (
    borrower_id SERIAL PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    phone VARCHAR(20),
    address TEXT,
    membership_date DATE NOT NULL DEFAULT CURRENT_DATE,
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    CONSTRAINT status_check CHECK (status IN ('ACTIVE', 'SUSPENDED', 'EXPIRED'))
);

CREATE TABLE book_copies (
    copy_id SERIAL PRIMARY KEY,
    book_id INT NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'AVAILABLE',
    condition VARCHAR(20) NOT NULL DEFAULT 'GOOD',
    acquisition_date DATE NOT NULL DEFAULT CURRENT_DATE,
    FOREIGN KEY (book_id) REFERENCES books(book_id),
    CONSTRAINT status_check CHECK (status IN ('AVAILABLE', 'BORROWED', 'RESERVED', 'MAINTENANCE')),
    CONSTRAINT condition_check CHECK (condition IN ('NEW', 'GOOD', 'FAIR', 'POOR', 'DAMAGED'))
);

CREATE TABLE loans (
    loan_id SERIAL PRIMARY KEY,
    copy_id INT NOT NULL,
    borrower_id INT NOT NULL,
    checkout_date DATE NOT NULL DEFAULT CURRENT_DATE,
    due_date DATE NOT NULL,
    return_date DATE,
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    FOREIGN KEY (copy_id) REFERENCES book_copies(copy_id),
    FOREIGN KEY (borrower_id) REFERENCES borrowers(borrower_id),
    CONSTRAINT status_check CHECK (status IN ('ACTIVE', 'RETURNED', 'OVERDUE')),
    CONSTRAINT date_check CHECK (
        (return_date IS NULL OR return_date >= checkout_date) AND
        due_date > checkout_date
    )
);

CREATE TABLE reservations (
    reservation_id SERIAL PRIMARY KEY,
    book_id INT NOT NULL,
    borrower_id INT NOT NULL,
    reservation_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expiry_date TIMESTAMP NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    FOREIGN KEY (book_id) REFERENCES books(book_id),
    FOREIGN KEY (borrower_id) REFERENCES borrowers(borrower_id),
    CONSTRAINT status_check CHECK (status IN ('PENDING', 'FULFILLED', 'CANCELLED', 'EXPIRED')),
    CONSTRAINT date_check CHECK (expiry_date > reservation_date)
);

CREATE TABLE fines (
    fine_id SERIAL PRIMARY KEY,
    loan_id INT NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    issued_date DATE NOT NULL DEFAULT CURRENT_DATE,
    paid_date DATE,
    status VARCHAR(20) NOT NULL DEFAULT 'UNPAID',
    FOREIGN KEY (loan_id) REFERENCES loans(loan_id),
    CONSTRAINT status_check CHECK (status IN ('UNPAID', 'PAID', 'WAIVED')),
    CONSTRAINT amount_check CHECK (amount >= 0),
    CONSTRAINT date_check CHECK (paid_date IS NULL OR paid_date >= issued_date)
);

-- Create indexes
CREATE INDEX idx_loans_borrower ON loans(borrower_id);
CREATE INDEX idx_loans_copy ON loans(copy_id);
CREATE INDEX idx_reservations_book ON reservations(book_id);
CREATE INDEX idx_reservations_borrower ON reservations(borrower_id);
CREATE INDEX idx_book_copies_status ON book_copies(status);
CREATE INDEX idx_fines_loan ON fines(loan_id);

-- V1.0.1__Insert_Sample_Data.sql
-- Insert Categories
INSERT INTO categories (name, description) VALUES
    ('Fiction', 'Fictional literature including novels and short stories'),
    ('Non-Fiction', 'Factual books including biographies and academic texts'),
    ('Science Fiction', 'Science fiction and fantasy literature'),
    ('Technology', 'Books about computing, programming, and technology');

-- Insert Books
INSERT INTO books (title, isbn, author, publisher, publication_year, category_id) VALUES
    ('The Great Gatsby', '9780743273565', 'F. Scott Fitzgerald', 'Scribner', 1925, 1),
    ('Clean Code', '9780132350884', 'Robert C. Martin', 'Prentice Hall', 2008, 4),
    ('Dune', '9780441172719', 'Frank Herbert', 'Ace Books', 1965, 3),
    ('The Pragmatic Programmer', '9780201616224', 'Andy Hunt, Dave Thomas', 'Addison-Wesley', 1999, 4);

-- Insert Book Copies
INSERT INTO book_copies (book_id, status, condition) 
SELECT book_id, 'AVAILABLE', 'GOOD'
FROM books;

-- Insert additional copies for some books
INSERT INTO book_copies (book_id, status, condition)
SELECT book_id, 'AVAILABLE', 'GOOD'
FROM books
WHERE title IN ('The Great Gatsby', 'Clean Code');

-- Insert Sample Borrowers
INSERT INTO borrowers (first_name, last_name, email, phone, status) VALUES
    ('John', 'Doe', 'john.doe@email.com', '1234567890', 'ACTIVE'),
    ('Jane', 'Smith', 'jane.smith@email.com', '0987654321', 'ACTIVE'),
    ('Robert', 'Johnson', 'robert.j@email.com', '5555555555', 'ACTIVE');

-- V1.0.2__Create_Functions.sql
-- Function to check if a borrower can borrow books
CREATE OR REPLACE FUNCTION can_borrow(p_borrower_id INT)
RETURNS BOOLEAN AS $$
DECLARE
    active_loans INT;
    has_unpaid_fines BOOLEAN;
BEGIN
    -- Check borrower status
    IF NOT EXISTS (
        SELECT 1 FROM borrowers 
        WHERE borrower_id = p_borrower_id 
        AND status = 'ACTIVE'
    ) THEN
        RETURN FALSE;
    END IF;

    -- Count active loans
    SELECT COUNT(*) INTO active_loans
    FROM loans
    WHERE borrower_id = p_borrower_id
    AND status = 'ACTIVE';

    -- Check for unpaid fines
    SELECT EXISTS (
        SELECT 1 FROM fines f
        JOIN loans l ON f.loan_id = l.loan_id
        WHERE l.borrower_id = p_borrower_id
        AND f.status = 'UNPAID'
    ) INTO has_unpaid_fines;

    -- Can borrow if: active status, less than 5 active loans, no unpaid fines
    RETURN active_loans < 5 AND NOT has_unpaid_fines;
END;
$$ LANGUAGE plpgsql;

-- Function to automatically create fine for overdue books
CREATE OR REPLACE FUNCTION create_overdue_fine()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status = 'OVERDUE' AND OLD.status = 'ACTIVE' THEN
        INSERT INTO fines (loan_id, amount, status)
        VALUES (NEW.loan_id, 10.00, 'UNPAID');  -- $10 flat fee for overdue books
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for overdue fines
CREATE TRIGGER trg_create_overdue_fine
AFTER UPDATE ON loans
FOR EACH ROW
WHEN (NEW.status = 'OVERDUE' AND OLD.status = 'ACTIVE')
EXECUTE FUNCTION create_overdue_fine();