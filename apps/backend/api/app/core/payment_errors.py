from typing import NoReturn

from fastapi import HTTPException


def raise_contract_error(
    status_code: int,
    code: str,
    message: str,
) -> NoReturn:
    """Raise an HTTPException formatted with the C1 contract error envelope."""
    raise HTTPException(
        status_code=status_code,
        detail={"code": code, "message": message},
    )
