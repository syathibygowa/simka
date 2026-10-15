// SIMKA PRO | src/lib/audit.js | v1.0 | Perbaikan 13.6.0: kategori aktivitas audit log | 15/10/2026
// Pengelompokan jenis data (tabel) audit log menjadi kategori aktivitas SIMKA PRO untuk kartu statistik dan saringan.
import { PhIdentificationCard, PhShieldCheck, PhFingerprint, PhStudent, PhBookOpenText, PhWallet, PhEnvelopeSimple, PhMegaphone, PhGearSix, PhDotsThreeCircle } from '@phosphor-icons/vue'

export const KATEGORI_AUDIT = [
  { k: 'pegawai', n: 'Kepegawaian', ikon: PhIdentificationCard, w: 'pegawai',
    t: ['employees', 'employee_functions', 'employee_structurals', 'employee_documents', 'employee_data_requests', 'employee_groups', 'employee_group_members',
        'acting_assignments', 'org_units', 'functional_positions', 'structural_positions', 'employee_cards', 'document_categories', 'workload_components',
        'employee_workloads', 'workload_snapshots', 'leave_types', 'leave_tiers'] },
  { k: 'akses', n: 'Hak akses', ikon: PhShieldCheck, w: 'hakakses', t: ['admin_permissions', 'feature_grants', 'sensitive_access'] },
  { k: 'presensi', n: 'Presensi dan jadwal', ikon: PhFingerprint, w: 'presensi',
    t: ['employee_schedules', 'task_patterns', 'pattern_sessions', 'shift_rosters', 'shift_swaps', 'gps_points', 'holidays', 'holiday_calendars',
        'holiday_eligibility', 'holiday_periods', 'journal_items', 'agendas'] },
  { k: 'santri', n: 'Santri dan layanan', ikon: PhStudent, w: 'santri',
    t: ['students', 'student_contacts', 'student_groups', 'group_keepers', 'group_members', 'student_permits', 'student_cards', 'student_achievements',
        'gate_logs', 'guest_logs', 'parcels', 'parent_visits', 'clinic_staff', 'guardian_sessions', 'guardian_login_attempts'] },
  { k: 'akademik', n: 'Akademik dan tahfizh', ikon: PhBookOpenText, w: 'tahfizh',
    t: ['academic_years', 'teaching_assignments', 'grade_categories', 'grade_change_requests', 'grade_columns', 'grade_finals', 'grade_objectives', 'grade_periods',
        'report_cocurricular', 'report_decisions', 'report_extracurricular', 'report_manual_scores', 'report_notes', 'report_phrases', 'report_predicates',
        'report_settings', 'report_subject_sources', 'report_subjects', 'predicate_ranges', 'student_tahfizh', 'tahfizh_examiners', 'tahfizh_exams',
        'tahfizh_settings', 'tahfizh_targets', 'tahfizh_documents', 'juz_proposals', 'juz_achievements', 'monthly_achievements', 'utas_examiners', 'utas_results'] },
  { k: 'keuangan', n: 'Gaji dan keuangan', ikon: PhWallet, w: 'keuangan',
    t: ['gaji', 'salary_rates', 'salary_decisions', 'employee_bank_accounts', 'employee_loans', 'loan_payments', 'savings_programs', 'savings_members',
        'savings_transactions', 'payroll_slip_requests', 'fee_types', 'fee_rates', 'fee_subsidies', 'bills', 'payments', 'payment_items', 'billing_letters'] },
  { k: 'surat', n: 'Persuratan', ikon: PhEnvelopeSimple, w: 'laporan',
    t: ['letter_templates', 'incoming_letters', 'outgoing_letters', 'letter_dispositions', 'letter_subject_codes', 'doc_number_formats'] },
  { k: 'pengumuman', n: 'Pengumuman', ikon: PhMegaphone, w: 'pengumuman', t: ['announcements', 'guardian_announcements'] },
  { k: 'pengaturan', n: 'Pengaturan', ikon: PhGearSix, w: 'pengaturan',
    t: ['institution_settings', 'letterheads', 'signatories', 'signer_rules', 'wa_templates', 'institution_logos'] },
]
export const KATEGORI_LAIN = { k: 'lain', n: 'Lainnya', ikon: PhDotsThreeCircle, w: 'sistem', t: [] }
const PETA = Object.fromEntries(KATEGORI_AUDIT.flatMap((k) => k.t.map((t) => [t, k.k])))
/** Kode kategori untuk jenis data (tabel) tertentu. */
export const kategoriTabel = (t) => PETA[t] || 'lain'
/** Semua tabel di luar kategori yang dikenal (untuk saringan "Lainnya") ditentukan dari ringkasan server. */
export const tabelKategori = (k, ringkasan = []) =>
  k === 'lain' ? [...new Set(ringkasan.map((r) => r.tabel).filter((t) => kategoriTabel(t) === 'lain'))] : (KATEGORI_AUDIT.find((x) => x.k === k)?.t || [])
