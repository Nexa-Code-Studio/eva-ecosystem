from io import BytesIO
import textwrap

from PIL import Image, ImageDraw, ImageFont

from app.models.certificate import PsychologistCertificate


def _hex_to_rgb(hex_color: str, fallback: tuple[int, int, int] = (37, 99, 235)) -> tuple[int, int, int]:
    cleaned = (hex_color or "").strip().lstrip("#")
    if len(cleaned) != 6:
        return fallback
    try:
        return (int(cleaned[0:2], 16), int(cleaned[2:4], 16), int(cleaned[4:6], 16))
    except ValueError:
        return fallback


def _font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    try:
        return ImageFont.load_default(size=size)
    except TypeError:
        return ImageFont.load_default()


def format_indonesian_issue_date(issued_at) -> str:
    months = [
        "Januari",
        "Februari",
        "Maret",
        "April",
        "Mei",
        "Juni",
        "Juli",
        "Agustus",
        "September",
        "Oktober",
        "November",
        "Desember",
    ]
    return f"{issued_at.day:02d} {months[issued_at.month - 1]} {issued_at.year}"


def render_certificate_pdf_bytes(cert: PsychologistCertificate) -> bytes:
    """Render an official A4-landscape EVA certificate PDF with watermark and digital signature."""
    width, height = 1600, 1120
    accent = _hex_to_rgb(cert.badge_color)
    dark_ink = (15, 23, 42)
    muted_ink = (71, 85, 105)
    soft_border = (203, 213, 225)

    canvas = Image.new("RGBA", (width, height), (252, 253, 254, 255))
    draw = ImageDraw.Draw(canvas)

    # Diagonal background watermark layer
    watermark_layer = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    wm_draw = ImageDraw.Draw(watermark_layer)
    wm_text = "TERVERIFIKASI EVA" if cert.status == "active" else "SERTIFIKAT DICABUT"
    wm_color = (accent[0], accent[1], accent[2], 18) if cert.status == "active" else (185, 28, 28, 24)
    wm_draw.text((width // 2, height // 2), wm_text, fill=wm_color, font=_font(96), anchor="mm")
    watermark_rotated = watermark_layer.rotate(18, resample=Image.Resampling.BICUBIC)
    canvas = Image.alpha_composite(canvas, watermark_rotated)
    draw = ImageDraw.Draw(canvas)

    # Ornate borders
    draw.rounded_rectangle([32, 32, width - 32, height - 32], radius=24, outline=accent, width=6)
    draw.rounded_rectangle([48, 48, width - 48, height - 48], radius=16, outline=soft_border, width=2)

    # Top header banner & badges
    draw.text(
        (width // 2, 110),
        "EKOSISTEM PSIKOLOGI DIGITAL EVA INDONESIA",
        fill=muted_ink,
        font=_font(20),
        anchor="mm",
    )
    draw.text(
        (width // 2, 162),
        cert.title.upper(),
        fill=accent,
        font=_font(38),
        anchor="mm",
    )
    draw.text(
        (width // 2, 206),
        cert.subtitle,
        fill=muted_ink,
        font=_font(22),
        anchor="mm",
    )
    draw.line([(460, 238), (width - 460, 238)], fill=accent, width=3)

    # Registration & STR line
    draw.text(
        (width // 2, 278),
        f"No. Sertifikat: {cert.certificate_number}   |   No. STR: {cert.str_number}",
        fill=dark_ink,
        font=_font(21),
        anchor="mm",
    )

    # Recipient block
    draw.text(
        (width // 2, 355),
        "Dengan bangga diberikan kepada:",
        fill=muted_ink,
        font=_font(24),
        anchor="mm",
    )
    draw.text(
        (width // 2, 418),
        cert.recipient_name,
        fill=dark_ink,
        font=_font(46),
        anchor="mm",
    )
    draw.line([(360, 456), (width - 360, 456)], fill=soft_border, width=2)

    # Milestone highlight pill
    draw.rounded_rectangle([340, 486, width - 340, 544], radius=12, fill=(238, 242, 255, 255), outline=accent, width=2)
    draw.text(
        (width // 2, 515),
        f"Pencapaian: {cert.milestone_criteria}",
        fill=accent,
        font=_font(23),
        anchor="mm",
    )

    # Wrapped official description
    wrapped_lines = textwrap.wrap(cert.description, width=78)[:4]
    y_cursor = 595
    for line in wrapped_lines:
        draw.text((width // 2, y_cursor), line, fill=muted_ink, font=_font(22), anchor="mm")
        y_cursor += 34

    # Footer: issue location/date, digital seal, and platform signature
    issue_label = format_indonesian_issue_date(cert.issued_at)
    draw.text(
        (220, 845),
        f"Diterbitkan di Jakarta, {issue_label}",
        fill=dark_ink,
        font=_font(20),
        anchor="lm",
    )
    draw.text(
        (220, 882),
        f"Kategori Mitra: {cert.category_label}",
        fill=muted_ink,
        font=_font(18),
        anchor="lm",
    )
    draw.text(
        (220, 916),
        f"Status Dokumen: {'SAH & TERVERIFIKASI' if cert.status == 'active' else 'DICABUT / TIDAK BERLAKU'}",
        fill=accent if cert.status == "active" else (185, 28, 28),
        font=_font(18),
        anchor="lm",
    )

    # Official Circular Seal
    seal_cx, seal_cy = width // 2, 885
    draw.ellipse([seal_cx - 72, seal_cy - 72, seal_cx + 72, seal_cy + 72], outline=accent, width=4)
    draw.ellipse([seal_cx - 60, seal_cy - 60, seal_cx + 60, seal_cy + 60], outline=accent, width=2)
    draw.text((seal_cx, seal_cy - 14), "EVA", fill=accent, font=_font(26), anchor="mm")
    draw.text((seal_cx, seal_cy + 18), "OFFICIAL SEAL", fill=accent, font=_font(13), anchor="mm")

    # Digital Signature Block
    sig_x = width - 350
    draw.text((sig_x, 825), "Ditandatangani secara elektronik:", fill=muted_ink, font=_font(17), anchor="mm")
    draw.line([(sig_x - 140, 885), (sig_x + 140, 885)], fill=dark_ink, width=2)
    draw.text((sig_x, 908), "Komite Kredensial Klinis EVA", fill=dark_ink, font=_font(20), anchor="mm")
    draw.text((sig_x, 938), "Empathetic Vitality Assistant Platform", fill=muted_ink, font=_font(16), anchor="mm")

    output = BytesIO()
    canvas.convert("RGB").save(output, format="PDF", resolution=150.0)
    return output.getvalue()
