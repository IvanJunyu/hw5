import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(QuizApp());
}

class QuizApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Customizable Quiz App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: SetupScreen(),
    );
  }
}

class SetupScreen extends StatefulWidget {
  @override
  _SetupScreenState createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  int _numberOfQuestions = 10;
  String _selectedCategory = "9"; // Default to General Knowledge
  String _selectedDifficulty = "medium";
  String _selectedType = "multiple";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.lightBlue[50],
      appBar: AppBar(title: Text('Quiz Setup')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Customize Your Quiz',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            _buildDropdown<int>(
              label: 'Number of Questions',
              value: _numberOfQuestions,
              items: [5, 10, 15],
              onChanged: (value) => setState(() => _numberOfQuestions = value!),
            ),
            _buildDropdown<String>(
              label: 'Category',
              value: _selectedCategory,
              items: [
                {'id': '9', 'name': 'General Knowledge'},
                {'id': '21', 'name': 'Sports'},
                {'id': '11', 'name': 'Movies'},
              ].map((category) => category['id']!).toList(),
              itemLabels: [
                'General Knowledge',
                'Sports',
                'Movies',
              ],
              onChanged: (value) => setState(() => _selectedCategory = value!),
            ),
            _buildDropdown<String>(
              label: 'Difficulty',
              value: _selectedDifficulty,
              items: ['easy', 'medium', 'hard'],
              onChanged: (value) => setState(() => _selectedDifficulty = value!),
            ),
            _buildDropdown<String>(
              label: 'Type',
              value: _selectedType,
              items: ['multiple', 'boolean'],
              itemLabels: ['Multiple Choice', 'True/False'],
              onChanged: (value) => setState(() => _selectedType = value!),
            ),
            Spacer(),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => QuizScreen(
                      numberOfQuestions: _numberOfQuestions,
                      category: _selectedCategory,
                      difficulty: _selectedDifficulty,
                      type: _selectedType,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 16)),
              child: Text(
                'Start Quiz',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T value,
    required List<T> items,
    List<String>? itemLabels,
    required ValueChanged<T?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: DropdownButtonFormField<T>(
        value: value,
        items: items
            .asMap()
            .entries
            .map(
              (entry) => DropdownMenuItem(
                value: entry.value,
                child: Text(itemLabels != null ? itemLabels[entry.key] : entry.value.toString()),
              ),
            )
            .toList(),
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }
}

class QuizScreen extends StatefulWidget {
  final int numberOfQuestions;
  final String category;
  final String difficulty;
  final String type;
  final List<Map<String, dynamic>>? questions;

  QuizScreen({
    required this.numberOfQuestions,
    required this.category,
    required this.difficulty,
    required this.type,
    this.questions,
  });

  @override
  _QuizScreenState createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  List<Map<String, dynamic>> _questions = [];
  List<Map<String, String>> _answers = [];
  int _currentQuestionIndex = 0;
  int _score = 0;
  bool _loading = true;
  bool _answered = false;
  String _selectedAnswer = "";
  String _feedbackText = "";
  Timer? _timer;
  int _timeRemaining = 15;

  @override
  void initState() {
    super.initState();
    if (widget.questions != null) {
      _questions = widget.questions!;
      _loading = false;
      _startTimer();
    } else {
      _loadQuestions();
    }
  }

  Future<void> _loadQuestions() async {
    try {
      final url =
          'https://opentdb.com/api.php?amount=${widget.numberOfQuestions}&category=${widget.category}&difficulty=${widget.difficulty}&type=${widget.type}';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _questions = data['results']
              .map<Map<String, dynamic>>((question) => _prepareQuestion(question))
              .toList();
          _loading = false;
          _startTimer();
        });
      } else {
        throw Exception('Failed to load questions');
      }
    } catch (e) {
      print(e);
    }
  }

  Map<String, dynamic> _prepareQuestion(Map<String, dynamic> question) {
    final options = List<String>.from(question['incorrect_answers']);
    options.add(question['correct_answer']);
    options.shuffle();

    return {
      'question': question['question'],
      'correct_answer': question['correct_answer'],
      'options': options,
    };
  }

  void _startTimer() {
    _timeRemaining = 15;
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _timeRemaining--;
        if (_timeRemaining <= 0) {
          timer.cancel();
          _timeExpired();
        }
      });
    });
  }

  void _timeExpired() {
    setState(() {
      _answered = true;
      _feedbackText = "Time's up! The correct answer is ${_questions[_currentQuestionIndex]['correct_answer']}.";
      _saveAnswer("Missed");
    });
  }

  void _submitAnswer(String selectedAnswer) {
    _timer?.cancel();
    setState(() {
      _answered = true;
      _selectedAnswer = selectedAnswer;

      final correctAnswer = _questions[_currentQuestionIndex]['correct_answer'];
      if (selectedAnswer == correctAnswer) {
        _score++;
        _feedbackText = "Correct! The answer is $correctAnswer.";
        _saveAnswer("Correct");
      } else {
        _feedbackText = "Incorrect. The correct answer is $correctAnswer.";
        _saveAnswer("Incorrect");
      }
    });
  }

  void _saveAnswer(String status) {
    _answers.add({
      'question': _questions[_currentQuestionIndex]['question'],
      'selected_answer': _selectedAnswer,
      'correct_answer': _questions[_currentQuestionIndex]['correct_answer'],
      'status': status,
    });
  }

  void _nextQuestion() {
    setState(() {
      _currentQuestionIndex++;
      _answered = false;
      _selectedAnswer = "";
      _feedbackText = "";
      if (_currentQuestionIndex < _questions.length) {
        _startTimer();
      } else {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: Colors.lightBlue[50],
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_currentQuestionIndex >= _questions.length) {
      return SummaryScreen(score: _score, answers: _answers, questions: _questions);
    }

    final question = _questions[_currentQuestionIndex];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: Text('Quiz')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Question ${_currentQuestionIndex + 1}/${_questions.length}',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 10),
            LinearProgressIndicator(
              value: (_currentQuestionIndex + 1) / _questions.length,
            ),
            SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.lightBlue[50],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                question['question'],
                style: TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: 20),
            ...question['options'].map<Widget>((option) {
              return ElevatedButton(
                onPressed: _answered ? null : () => _submitAnswer(option),
                child: Text(option),
              );
            }).toList(),
            if (_answered)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Text(
                  _feedbackText,
                  style: TextStyle(
                    fontSize: 16,
                    color: _selectedAnswer == question['correct_answer']
                        ? Colors.green
                        : Colors.red,
                  ),
                ),
              ),
            if (_answered)
              ElevatedButton(
                onPressed: _nextQuestion,
                child: Text('Next Question'),
              ),
            Spacer(),
            Text(
              'Time Remaining: $_timeRemaining seconds',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class SummaryScreen extends StatelessWidget {
  final int score;
  final List<Map<String, String>> answers;
  final List<Map<String, dynamic>> questions;

  SummaryScreen({
    required this.score,
    required this.answers,
    required this.questions,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.lightBlue[50],
      appBar: AppBar(title: Text('Quiz Summary')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Quiz Finished! Your Score: $score/${answers.length}',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: answers.length,
                itemBuilder: (context, index) {
                  final answer = answers[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Q${index + 1}: ${answer['question']!}',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 5),
                          Text('Your Answer: ${answer['selected_answer'] ?? "Missed"}'),
                          Text('Correct Answer: ${answer['correct_answer']}'),
                          Text('Status: ${answer['status']}'),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => QuizScreen(
                      numberOfQuestions: questions.length,
                      category: "0",
                      difficulty: "0",
                      type: "0",
                      questions: questions,
                    ),
                  ),
                );
              },
              child: Text('Retake Quiz'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
              child: Text('Back to Setup'),
            ),
          ],
        ),
      ),
    );
  }
}
