import 'package:supabase/supabase.dart';
import 'dart:io';

void main() async {
  final supabase = SupabaseClient(
    'https://tcuacymaavmiruanyfsv.supabase.co',
    'sb_publishable_7zyOnxq66A7MUhahKpFbIg_9pXT42or',
  );

  // We can't query normally because RLS will block us since we don't have a session.
  // We need to login as Maria and Clovis to test their access.
  print('In order to test, we need emails and passwords, which we dont have.');
  
  exit(0);
}
