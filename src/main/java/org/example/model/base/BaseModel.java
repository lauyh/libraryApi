package org.example.model.base;

import jakarta.persistence.Id;
import jakarta.persistence.MappedSuperclass;
import lombok.Data;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.util.UUID;

@Data
@MappedSuperclass
public class BaseModel {
    @Id
    @JdbcTypeCode(SqlTypes.UUID)
    private UUID id;
}
