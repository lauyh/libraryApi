package org.example.controller;

import com.library.model.Fine;
import org.springframework.http.ResponseEntity;

import java.util.List;
import java.util.Optional;

public class BorrowersController implements com.library.api.BorrowersApi {
    @Override
    public ResponseEntity<List<Fine>> _getBorrowerFines(Long borrowerId, Optional<String> status) {
        return null;
    }
}
