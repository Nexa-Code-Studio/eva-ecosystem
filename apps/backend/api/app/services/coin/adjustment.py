from fastapi import HTTPException, status


def resolve_coin_adjustment_delta(mode: str, amount: int, current_balance: int) -> tuple[int, str]:
    """Validate an admin coin adjustment and return ``(signed_delta, mode_label)``."""
    if mode == "add":
        if amount < 1:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Nominal penambahan koin minimal 1.",
            )
        return amount, "Penambahan Koin Admin"

    if mode == "deduct":
        if amount < 1:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Nominal pengurangan koin minimal 1.",
            )
        if amount > current_balance:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Pengurangan ({amount} Koin) melebihi saldo saat ini ({current_balance} Koin).",
            )
        return -amount, "Pengurangan Koin Admin"

    if mode == "set":
        if amount < 0:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Target saldo koin tidak boleh negatif.",
            )
        delta = amount - current_balance
        if delta == 0:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Target saldo sama dengan saldo koin saat ini.",
            )
        return delta, "Set Saldo Koin Admin"

    raise HTTPException(
        status_code=status.HTTP_400_BAD_REQUEST,
        detail="Mode penyesuaian koin tidak valid.",
    )
