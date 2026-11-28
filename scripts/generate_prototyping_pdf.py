import os
from reportlab.lib.pagesizes import A4
from reportlab.lib import colors
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, Image, KeepTogether, HRFlowable
)
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm

def build_pdf(filename="docs/kumpulan_link_prototyping.pdf"):
    doc = SimpleDocTemplate(
        filename,
        pagesize=A4,
        leftMargin=1.8 * cm,
        rightMargin=1.8 * cm,
        topMargin=1.8 * cm,
        bottomMargin=1.8 * cm,
    )
    
    styles = getSampleStyleSheet()
    
    # Custom color palette
    c_primary = colors.HexColor("#1A2B4C")    # Navy deep
    c_teal = colors.HexColor("#0D9488")       # Teal accent
    c_body = colors.HexColor("#334155")       # Slate body
    c_card_bg = colors.HexColor("#F8FAFC")    # Light soft bg
    c_card_border = colors.HexColor("#E2E8F0")# Border gray
    c_badge_bg = colors.HexColor("#F1F5F9")   # Light badge
    c_badge_text = colors.HexColor("#475569") # Badge text
    c_link = colors.HexColor("#2563EB")       # Link blue
    
    # Paragraph styles
    title_style = ParagraphStyle(
        'DocTitle',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=18,
        leading=22,
        textColor=c_primary,
        spaceAfter=4,
    )
    
    subtitle_style = ParagraphStyle(
        'DocSubTitle',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=9.5,
        leading=14,
        textColor=c_body,
        spaceAfter=12,
    )
    
    card_title_style = ParagraphStyle(
        'CardTitle',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=11.5,
        leading=15,
        textColor=c_primary,
    )
    
    badge_style = ParagraphStyle(
        'BadgeText',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=8,
        leading=10,
        textColor=c_badge_text,
        alignment=2, # Right aligned
    )
    
    link_style = ParagraphStyle(
        'LinkText',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=9,
        leading=13,
        textColor=c_link,
        spaceAfter=6,
    )
    
    desc_style = ParagraphStyle(
        'DescText',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=9,
        leading=13.5,
        textColor=c_body,
    )
    
    footer_style = ParagraphStyle(
        'FooterText',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=8,
        leading=11,
        textColor=colors.HexColor("#94A3B8"),
        alignment=1, # Center
    )

    story = []

    # Header section with Logo & Title
    logo_path = "apps/eva_counselor_mobile/assets/images/luna_logo.png"
    if not os.path.exists(logo_path):
        logo_path = "apps/web/public/eva_logo.png"
    subtitle_text = (
        "Kompilasi akses landing page resmi serta unduhan aplikasi mobile Android (APK) "
        "melalui GitHub Releases."
    )
    if os.path.exists(logo_path):
        logo_img = Image(logo_path, width=1.1 * cm, height=1.1 * cm)
        header_table = Table(
            [
                [
                    logo_img,
                    [
                        Paragraph("Direktori Tautan Ekosistem EVA", title_style),
                        Paragraph(subtitle_text, subtitle_style)
                    ]
                ]
            ],
            colWidths=[1.4 * cm, 16.0 * cm]
        )
        header_table.setStyle(TableStyle([
            ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
            ('LEFTPADDING', (0,0), (-1,-1), 0),
            ('RIGHTPADDING', (0,0), (-1,-1), 0),
            ('TOPPADDING', (0,0), (-1,-1), 0),
            ('BOTTOMPADDING', (0,0), (-1,-1), 0),
        ]))
        story.append(header_table)
    else:
        story.append(Paragraph("Direktori Tautan Ekosistem EVA", title_style))
        story.append(Paragraph(subtitle_text, subtitle_style))

    story.append(Spacer(1, 0.2 * cm))
    story.append(HRFlowable(width="100%", thickness=1, color=c_card_border, spaceBefore=0, spaceAfter=14))

    # Items data: (title, badge, url, url_display, description)
    # Notice: strictly no hyphen bullet points, no "subheading: explanation", no excessive bold
    items = [
        (
            "Landing Page & Portal Web EVA",
            "Web Resmi Aktif",
            "https://hieva.web.id",
            "hieva.web.id",
            "Halaman utama resmi Ekosistem EVA yang memuat informasi layanan, panduan penggunaan, tautan unduhan aplikasi, serta akses menuju portal manajemen web dan mitra profesional."
        ),
        (
            "Aplikasi Mobile Pasien (EVA Mobile)",
            "Android APK · GitHub Release",
            "https://github.com/Nexa-Code-Studio/eva-ecosystem/releases/latest/download/eva-mobile-release.apk",
            "github.com/Nexa-Code-Studio/eva-ecosystem/.../eva-mobile-release.apk",
            "Berkas instalasi Android (.apk) rilis terbaru untuk aplikasi pengguna akhir, mencakup fitur curhat suara bersama EVA AI, skrining kesehatan mental, jurnal reflektif, misi pemulihan harian, dan konsultasi psikolog."
        ),
        (
            "Aplikasi Mobile Konselor (EVA Counselor)",
            "Android APK · GitHub Release",
            "https://github.com/Nexa-Code-Studio/eva-ecosystem/releases/latest/download/eva-counselor-mobile-release.apk",
            "github.com/Nexa-Code-Studio/eva-ecosystem/.../eva-counselor-mobile-release.apk",
            "Berkas instalasi Android (.apk) rilis terbaru untuk tenaga psikolog dan konselor mitra, mencakup pengelolaan jadwal praktik, pelaksanaan sesi telekonsultasi, dokumentasi klinis, dan pemantauan dompet koin."
        ),
    ]

    for title, badge, url, url_disp, desc in items:
        # Top row: Title and Badge
        card_header_table = Table(
            [
                [
                    Paragraph(title, card_title_style),
                    Paragraph(f"<font color='#0D9488'>●</font> {badge}", badge_style)
                ]
            ],
            colWidths=[10.5 * cm, 6.0 * cm]
        )
        card_header_table.setStyle(TableStyle([
            ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
            ('LEFTPADDING', (0,0), (-1,-1), 0),
            ('RIGHTPADDING', (0,0), (-1,-1), 0),
            ('TOPPADDING', (0,0), (-1,-1), 0),
            ('BOTTOMPADDING', (0,0), (-1,-1), 4),
        ]))
        
        # Link paragraph with underline and clickability
        link_p = Paragraph(f'<link href="{url}"><u><font color="#2563EB">{url}</font></u></link>', link_style)
        
        # Description paragraph
        desc_p = Paragraph(desc, desc_style)
        
        # Wrap everything in a clean bordered card
        card_content = [
            [card_header_table],
            [link_p],
            [desc_p]
        ]
        
        card_table = Table(card_content, colWidths=[17.2 * cm])
        card_table.setStyle(TableStyle([
            ('BACKGROUND', (0,0), (-1,-1), c_card_bg),
            ('BOX', (0,0), (-1,-1), 0.75, c_card_border),
            ('LEFTPADDING', (0,0), (-1,-1), 12),
            ('RIGHTPADDING', (0,0), (-1,-1), 12),
            ('TOPPADDING', (0,0), (-1,-1), 10),
            ('BOTTOMPADDING', (0,0), (-1,-1), 10),
        ]))
        
        story.append(card_table)
        story.append(Spacer(1, 0.35 * cm))

    # Notes section at bottom
    story.append(Spacer(1, 0.2 * cm))
    note_p = Paragraph(
        "Seluruh tautan di atas dapat diklik langsung untuk membuka halaman web atau mengunduh "
        "berkas APK rilis terbaru pada perangkat Android Anda.",
        footer_style
    )
    story.append(note_p)

    doc.build(story)
    print(f"PDF successfully built: {filename}")

if __name__ == "__main__":
    build_pdf("docs/kumpulan_link_prototyping.pdf")
