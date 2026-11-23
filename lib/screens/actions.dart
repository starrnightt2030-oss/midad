import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../state/library.dart';
import '../state/player.dart';
import '../widgets/common.dart';
import 'live_read_screen.dart';
import 'player_screen.dart';
import 'reader_screen.dart';

/// يبدأ الاستماع ويفتح المشغّل.
void listenTo(BuildContext context, Work w, {int chapter = 0}) {
  context.read<PlayerController>().open(w, chapter: chapter);
  context.read<LibraryStore>().touch(w.id, chapter);
  Navigator.of(context).push(sheetRoute(const PlayerScreen()));
}

/// القراءة الحية (النص يظهر مع الصوت).
void liveRead(BuildContext context, Work w, {int chapter = 0}) {
  context.read<PlayerController>().open(w, chapter: chapter);
  context.read<LibraryStore>().touch(w.id, chapter);
  Navigator.of(context).push(fadeRoute(const LiveReadScreen()));
}

/// القراءة كصفحة (الصوت متاح لكن لا يبدأ تلقائيًا).
void readPage(BuildContext context, Work w, {int chapter = 0}) {
  context.read<PlayerController>().open(w, chapter: chapter, autoplay: false);
  context.read<LibraryStore>().touch(w.id, chapter);
  Navigator.of(context).push(fadeRoute(const ReaderScreen()));
}
