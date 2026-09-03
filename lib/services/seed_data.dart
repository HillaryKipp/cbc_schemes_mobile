import '../models/grade.dart';
import '../models/subject.dart';
import '../models/strand.dart';
import '../models/reference_book.dart';
import '../models/content_bank.dart';
import '../models/term_template.dart';
import '../models/app_settings.dart';

class SeedData {
  static List<Grade> get defaultGrades => [
    Grade(id: 'grade-pp1', name: 'PP1', level: 'Pre-Primary', orderIndex: 1),
    Grade(id: 'grade-pp2', name: 'PP2', level: 'Pre-Primary', orderIndex: 2),
    Grade(id: 'grade-1', name: 'Grade 1', level: 'Lower Primary', orderIndex: 3),
    Grade(id: 'grade-2', name: 'Grade 2', level: 'Lower Primary', orderIndex: 4),
    Grade(id: 'grade-3', name: 'Grade 3', level: 'Lower Primary', orderIndex: 5),
    Grade(id: 'grade-4', name: 'Grade 4', level: 'Upper Primary', orderIndex: 6),
    Grade(id: 'grade-5', name: 'Grade 5', level: 'Upper Primary', orderIndex: 7),
    Grade(id: 'grade-6', name: 'Grade 6', level: 'Upper Primary', orderIndex: 8),
    Grade(id: 'grade-7', name: 'Grade 7', level: 'Junior School', orderIndex: 9),
    Grade(id: 'grade-8', name: 'Grade 8', level: 'Junior School', orderIndex: 10),
    Grade(id: 'grade-9', name: 'Grade 9', level: 'Junior School', orderIndex: 11),
  ];

  static List<Subject> get defaultSubjects => [
    // Grade 3 subjects
    Subject(id: 'subj-g3-math', gradeId: 'grade-3', name: 'Mathematics Activities', code: 'MATH', orderIndex: 1),
    Subject(id: 'subj-g3-eng', gradeId: 'grade-3', name: 'English Language Activities', code: 'ENG', orderIndex: 2),
    Subject(id: 'subj-g3-kisw', gradeId: 'grade-3', name: 'Kiswahili Shughuli za Lugha', code: 'KISW', orderIndex: 3),
    Subject(id: 'subj-g3-env', gradeId: 'grade-3', name: 'Environmental Activities', code: 'ENV', orderIndex: 4),
    Subject(id: 'subj-g3-cre', gradeId: 'grade-3', name: 'Christian Religious Education (CRE)', code: 'CRE', orderIndex: 5),

    // Grade 4-6 subjects
    Subject(id: 'subj-g4-math', gradeId: 'grade-4', name: 'Mathematics', code: 'MATH', orderIndex: 1),
    Subject(id: 'subj-g4-sci', gradeId: 'grade-4', name: 'Science and Technology', code: 'SCI', orderIndex: 2),
    Subject(id: 'subj-g4-agri', gradeId: 'grade-4', name: 'Agriculture and Nutrition', code: 'AGRI', orderIndex: 3),
    Subject(id: 'subj-g4-eng', gradeId: 'grade-4', name: 'English', code: 'ENG', orderIndex: 4),
    Subject(id: 'subj-g4-kisw', gradeId: 'grade-4', name: 'Kiswahili', code: 'KISW', orderIndex: 5),
    Subject(id: 'subj-g4-soc', gradeId: 'grade-4', name: 'Social Studies', code: 'SOC', orderIndex: 6),
    Subject(id: 'subj-g4-art', gradeId: 'grade-4', name: 'Creative Arts', code: 'ART', orderIndex: 7),

    // Grade 7 Junior School subjects
    Subject(id: 'subj-g7-math', gradeId: 'grade-7', name: 'Mathematics', code: 'MATH', orderIndex: 1),
    Subject(id: 'subj-g7-intsci', gradeId: 'grade-7', name: 'Integrated Science', code: 'INTSCI', orderIndex: 2),
    Subject(id: 'subj-g7-agri', gradeId: 'grade-7', name: 'Agriculture', code: 'AGRI', orderIndex: 3),
    Subject(id: 'subj-g7-eng', gradeId: 'grade-7', name: 'English', code: 'ENG', orderIndex: 4),
    Subject(id: 'subj-g7-kisw', gradeId: 'grade-7', name: 'Kiswahili', code: 'KISW', orderIndex: 5),
    Subject(id: 'subj-g7-soc', gradeId: 'grade-7', name: 'Social Studies', code: 'SOC', orderIndex: 6),
    Subject(id: 'subj-g7-crearts', gradeId: 'grade-7', name: 'Creative Arts & Sports', code: 'CREARTS', orderIndex: 7),
    Subject(id: 'subj-g7-pretech', gradeId: 'grade-7', name: 'Pre-Technical Studies', code: 'PRETECH', orderIndex: 8),
  ];

  static List<ReferenceBook> get defaultReferenceBooks => [
    ReferenceBook(
      id: 'book-klb-topmark-g7-math',
      subjectId: 'subj-g7-math',
      title: 'Top Mark Mathematics Learner\'s Book Grade 7',
      publisher: 'KLB (Kenya Literature Bureau)',
      edition: 'KICD Approved 2024',
    ),
    ReferenceBook(
      id: 'book-oxford-g7-math',
      subjectId: 'subj-g7-math',
      title: 'Advancing in Mathematics Grade 7',
      publisher: 'Oxford University Press',
      edition: 'KICD Approved 2024',
    ),
    ReferenceBook(
      id: 'book-longhorn-g7-math',
      subjectId: 'subj-g7-math',
      title: 'Longhorn Mathematics Grade 7',
      publisher: 'Longhorn Publishers',
      edition: 'KICD Approved',
    ),
    ReferenceBook(
      id: 'book-klb-g4-math',
      subjectId: 'subj-g4-math',
      title: 'KLB Early Bird Mathematics Grade 4',
      publisher: 'KLB',
      edition: 'Approved Edition',
    ),
    ReferenceBook(
      id: 'book-klb-g7-intsci',
      subjectId: 'subj-g7-intsci',
      title: 'Top Mark Integrated Science Grade 7',
      publisher: 'KLB',
      edition: 'KICD Approved',
    ),
  ];

  static List<Strand> get defaultStrands => [
    // Mathematics Grade 7 Strands & Sub-strands
    Strand(
      id: 'strand-g7-math-1',
      subjectId: 'subj-g7-math',
      name: '1.0 Numbers',
      orderIndex: 1,
      subStrands: [
        SubStrand(id: 'sub-g7-math-1-1', strandId: 'strand-g7-math-1', name: '1.1 Whole Numbers', suggestedLessons: 4, orderIndex: 1),
        SubStrand(id: 'sub-g7-math-1-2', strandId: 'strand-g7-math-1', name: '1.2 Factors and Multiples', suggestedLessons: 4, orderIndex: 2),
        SubStrand(id: 'sub-g7-math-1-3', strandId: 'strand-g7-math-1', name: '1.3 Fractions', suggestedLessons: 5, orderIndex: 3),
        SubStrand(id: 'sub-g7-math-1-4', strandId: 'strand-g7-math-1', name: '1.4 Decimals', suggestedLessons: 5, orderIndex: 4),
        SubStrand(id: 'sub-g7-math-1-5', strandId: 'strand-g7-math-1', name: '1.5 Squares and Square Roots', suggestedLessons: 4, orderIndex: 5),
      ],
    ),
    Strand(
      id: 'strand-g7-math-2',
      subjectId: 'subj-g7-math',
      name: '2.0 Algebra',
      orderIndex: 2,
      subStrands: [
        SubStrand(id: 'sub-g7-math-2-1', strandId: 'strand-g7-math-2', name: '2.1 Algebraic Expressions', suggestedLessons: 5, orderIndex: 1),
        SubStrand(id: 'sub-g7-math-2-2', strandId: 'strand-g7-math-2', name: '2.2 Linear Equations', suggestedLessons: 5, orderIndex: 2),
        SubStrand(id: 'sub-g7-math-2-3', strandId: 'strand-g7-math-2', name: '2.3 Linear Inequalities', suggestedLessons: 4, orderIndex: 3),
      ],
    ),
    Strand(
      id: 'strand-g7-math-3',
      subjectId: 'subj-g7-math',
      name: '3.0 Measurements',
      orderIndex: 3,
      subStrands: [
        SubStrand(id: 'sub-g7-math-3-1', strandId: 'strand-g7-math-3', name: '3.1 Pythagorean Relationship', suggestedLessons: 4, orderIndex: 1),
        SubStrand(id: 'sub-g7-math-3-2', strandId: 'strand-g7-math-3', name: '3.2 Length and Perimeter', suggestedLessons: 4, orderIndex: 2),
        SubStrand(id: 'sub-g7-math-3-3', strandId: 'strand-g7-math-3', name: '3.3 Area of Quadrilaterals', suggestedLessons: 5, orderIndex: 3),
        SubStrand(id: 'sub-g7-math-3-4', strandId: 'strand-g7-math-3', name: '3.4 Money and Financial Literacy', suggestedLessons: 4, orderIndex: 4),
      ],
    ),
    Strand(
      id: 'strand-g7-math-4',
      subjectId: 'subj-g7-math',
      name: '4.0 Geometry & Data Handling',
      orderIndex: 4,
      subStrands: [
        SubStrand(id: 'sub-g7-math-4-1', strandId: 'strand-g7-math-4', name: '4.1 Angles and Parallel Lines', suggestedLessons: 4, orderIndex: 1),
        SubStrand(id: 'sub-g7-math-4-2', strandId: 'strand-g7-math-4', name: '4.2 Geometrical Constructions', suggestedLessons: 4, orderIndex: 2),
        SubStrand(id: 'sub-g7-math-4-3', strandId: 'strand-g7-math-4', name: '4.3 Data Collection and Presentation', suggestedLessons: 4, orderIndex: 3),
      ],
    ),
  ];

  static List<LearningOutcome> get defaultOutcomes => [
    LearningOutcome(
      id: 'out-1',
      subStrandId: 'sub-g7-math-1-1',
      content: 'By the end of the sub-strand, the learner should be able to: identify place value and total value of digits up to hundreds of millions, read and write numbers in symbols and words, apply rounding off in real life contexts.',
    ),
    LearningOutcome(
      id: 'out-2',
      subStrandId: 'sub-g7-math-1-2',
      content: 'By the end of the sub-strand, the learner should be able to: express composite numbers as products of prime factors, find GCD and LCM of numbers, solve real life problems involving GCD and LCM.',
    ),
    LearningOutcome(
      id: 'out-3',
      subStrandId: 'sub-g7-math-1-3',
      content: 'By the end of the sub-strand, the learner should be able to: add and subtract proper, improper and mixed fractions, multiply and divide fractions, apply BODMAS rule in operations involving fractions.',
    ),
    LearningOutcome(
      id: 'out-4',
      subStrandId: 'sub-g7-math-1-4',
      content: 'By the end of the sub-strand, the learner should be able to: convert fractions to recurring/terminating decimals, perform four basic operations on decimals, round off decimals to specified decimal places.',
    ),
    LearningOutcome(
      id: 'out-5',
      subStrandId: 'sub-g7-math-2-1',
      content: 'By the end of the sub-strand, the learner should be able to: form algebraic expressions from real life situations, simplify algebraic expressions by grouping like terms, evaluate algebraic expressions by substitution.',
    ),
    LearningOutcome(
      id: 'out-6',
      subStrandId: 'sub-g7-math-3-1',
      content: 'By the end of the sub-strand, the learner should be able to: state the Pythagorean theorem, calculate length of hypotenuse and legs of a right-angled triangle, apply Pythagorean theorem to solve daily life problems.',
    ),
  ];

  static List<KeyInquiryQuestion> get defaultQuestions => [
    KeyInquiryQuestion(id: 'kiq-1', subStrandId: 'sub-g7-math-1-1', question: 'How is place value used in counting and recording large quantities in daily life?'),
    KeyInquiryQuestion(id: 'kiq-2', subStrandId: 'sub-g7-math-1-2', question: 'How do GCD and LCM help in sharing resources and scheduling repetitive events?'),
    KeyInquiryQuestion(id: 'kiq-3', subStrandId: 'sub-g7-math-1-3', question: 'Why is it important to follow order of operations when calculating fractions?'),
    KeyInquiryQuestion(id: 'kiq-4', subStrandId: 'sub-g7-math-1-4', question: 'How do decimal numbers represent precise measurements in trade and science?'),
    KeyInquiryQuestion(id: 'kiq-5', subStrandId: 'sub-g7-math-2-1', question: 'How can symbols and letters be used to simplify everyday mathematical problems?'),
    KeyInquiryQuestion(id: 'kiq-6', subStrandId: 'sub-g7-math-3-1', question: 'How do builders and constructors ensure corners are perfectly square?'),
  ];

  static List<LearningExperience> get defaultExperiences => [
    LearningExperience(id: 'exp-1', subStrandId: 'sub-g7-math-1-1', description: 'Learners in pairs or groups make number cards and read large numbers; use place value charts to represent digits up to millions.'),
    LearningExperience(id: 'exp-2', subStrandId: 'sub-g7-math-1-2', description: 'Learners use factor trees to write prime factorization; collaborate to solve LCM problems involving flashing lights/alarm intervals.'),
    LearningExperience(id: 'exp-3', subStrandId: 'sub-g7-math-1-3', description: 'Learners manipulate fraction cut-outs and strips; practice division of fractions using reciprocal models in group activities.'),
    LearningExperience(id: 'exp-4', subStrandId: 'sub-g7-math-1-4', description: 'Learners calculate totals from supermarket receipts; measure water volumes in litres with decimal gradations.'),
    LearningExperience(id: 'exp-5', subStrandId: 'sub-g7-math-2-1', description: 'Learners match verbal statements with corresponding algebraic cards; substitute values to verify answers in pairs.'),
    LearningExperience(id: 'exp-6', subStrandId: 'sub-g7-math-3-1', description: 'Learners construct right-angled triangles using 3-4-5 rope loops; verify area of squares on hypotenuse and legs on grid paper.'),
  ];

  static List<LearningResource> get defaultResources => [
    LearningResource(id: 'res-1', subStrandId: 'sub-g7-math-1-1', title: 'KICD Curriculum Design, KLB Learner\'s Book pg 1-14, Place value charts, Number cards, Abacus'),
    LearningResource(id: 'res-2', subStrandId: 'sub-g7-math-1-2', title: 'KLB Mathematics pg 15-28, Factor tree charts, Counters, Prime number grids'),
    LearningResource(id: 'res-3', subStrandId: 'sub-g7-math-1-3', title: 'Fraction charts, Paper cut-outs, KLB Mathematics pg 29-45, Ruler, Digital calculators'),
    LearningResource(id: 'res-4', subStrandId: 'sub-g7-math-1-4', title: 'Supermarket price tags, Measuring cylinders, KLB Learner\'s Book pg 46-60, Graph paper'),
    LearningResource(id: 'res-5', subStrandId: 'sub-g7-math-2-1', title: 'Algebra tiles, Flash cards, KLB Grade 7 Mathematics pg 61-78, Mathematical sets'),
    LearningResource(id: 'res-6', subStrandId: 'sub-g7-math-3-1', title: 'Grid paper, Metre rule, Strings/ropes, Protractor, KLB Mathematics pg 79-95'),
  ];

  static List<AssessmentMethod> get defaultAssessments => [
    AssessmentMethod(id: 'asm-1', name: 'Oral Questions and Classroom Observation', isGlobal: true),
    AssessmentMethod(id: 'asm-2', name: 'Written Quizzes and Exercise Book Checks', isGlobal: true),
    AssessmentMethod(id: 'asm-3', name: 'Group Presentation and Peer Assessment', isGlobal: true),
    AssessmentMethod(id: 'asm-4', name: 'Teacher-made Tests and Practical Tasks', isGlobal: true),
    AssessmentMethod(id: 'asm-5', name: 'Portfolio and Project Work', isGlobal: true),
  ];

  static List<TermTemplate> get defaultTermTemplates => [
    TermTemplate(
      id: 'term-1',
      termName: 'Term 1',
      year: 2026,
      defaultWeeks: 13,
      defaultLessonsPerWeek: 5,
      startDate: DateTime(2026, 1, 6),
      endDate: DateTime(2026, 4, 3),
      halfTermStart: DateTime(2026, 2, 18),
      halfTermEnd: DateTime(2026, 2, 22),
    ),
    TermTemplate(
      id: 'term-2',
      termName: 'Term 2',
      year: 2026,
      defaultWeeks: 14,
      defaultLessonsPerWeek: 5,
      startDate: DateTime(2026, 4, 28),
      endDate: DateTime(2026, 7, 31),
      halfTermStart: DateTime(2026, 6, 20),
      halfTermEnd: DateTime(2026, 6, 24),
    ),
    TermTemplate(
      id: 'term-3',
      termName: 'Term 3',
      year: 2026,
      defaultWeeks: 9,
      defaultLessonsPerWeek: 5,
      startDate: DateTime(2026, 8, 25),
      endDate: DateTime(2026, 10, 23),
    ),
  ];

  static AppSettings get defaultAppSettings => AppSettings(
    paymentsEnabled: false,
    adsEnabled: false,
    pricePerScheme: 100.0,
    currency: 'KES',
    supportPhone: '+254700000000',
    supportEmail: 'ruttohkip4@gmail.com',
  );
}
