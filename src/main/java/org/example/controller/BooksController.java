package org.example.controller;

import com.library.model.Book;
import com.library.model.ValidateIsbnFormat200Response;
import com.library.model.ValidateIsbnFormatRequest;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Controller;


@Controller
public class BooksController implements com.library.api.BooksApi {

    @Override
    public ResponseEntity<Book> _getBookByIsbn(String isbn) {
        return null;
    }

    @Override
    public ResponseEntity<ValidateIsbnFormat200Response> _validateIsbnFormat(ValidateIsbnFormatRequest validateIsbnFormatRequest) {
        return null;
    }
}
