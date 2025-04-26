Table Books {
  BookID int [pk]
  Title varchar
  Author varchar
  CopiesAvailable int
  TotalCopies int
}

Table Members {
  MemberID int [pk]
  Name varchar
  Email varchar
  TotalBooksBorrowed int
  IsActive boolean
}

Table BorrowedBooks {
  BorrowID int [pk]
  MemberID int [ref: > Members.MemberID]
  BookID int [ref: > Books.BookID]
  BorrowDate date
  DueDate date
  ReturnDate date
  IsReturned boolean
}
