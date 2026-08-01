-- Migration 003: Podcast profiles (seed) + default Mistral models
-- Mirrors the preinstalled profiles and discovered models present in the
-- original open-notebook app.

-- ============================================
-- Extend speaker_profiles (original shape)
-- ============================================
ALTER TABLE speaker_profiles ADD COLUMN speakers TEXT DEFAULT '[]';
ALTER TABLE speaker_profiles ADD COLUMN voice_settings TEXT;

-- ============================================
-- Extend episode_profiles (original shape)
-- ============================================
ALTER TABLE episode_profiles ADD COLUMN speaker_config TEXT;
ALTER TABLE episode_profiles ADD COLUMN outline_llm TEXT;
ALTER TABLE episode_profiles ADD COLUMN transcript_llm TEXT;
ALTER TABLE episode_profiles ADD COLUMN language TEXT;
ALTER TABLE episode_profiles ADD COLUMN default_briefing TEXT DEFAULT '';
ALTER TABLE episode_profiles ADD COLUMN num_segments INTEGER DEFAULT 5;
ALTER TABLE episode_profiles ADD COLUMN max_tokens INTEGER;

-- ============================================
-- Extend podcast_episodes (original shape)
-- ============================================
ALTER TABLE podcast_episodes ADD COLUMN name TEXT DEFAULT '';
ALTER TABLE podcast_episodes ADD COLUMN episode_profile_name TEXT;
ALTER TABLE podcast_episodes ADD COLUMN speaker_profile_name TEXT;
ALTER TABLE podcast_episodes ADD COLUMN briefing TEXT;
ALTER TABLE podcast_episodes ADD COLUMN job_status TEXT DEFAULT 'new';
ALTER TABLE podcast_episodes ADD COLUMN error_message TEXT;

-- ============================================
-- Seed default Mistral models (same set the
-- original app has after provider discovery)
-- ============================================
INSERT OR IGNORE INTO models (id, name, provider, type, created, updated) VALUES
('model-mistral-codestral-latest-language', 'codestral-latest', 'mistral', 'language', datetime('now'), datetime('now')),
('model-mistral-mistral-large-latest-language', 'mistral-large-latest', 'mistral', 'language', datetime('now'), datetime('now')),
('model-mistral-mistral-ocr-latest-language', 'mistral-ocr-latest', 'mistral', 'language', datetime('now'), datetime('now')),
('model-mistral-codestral-embed-embedding', 'codestral-embed', 'mistral', 'embedding', datetime('now'), datetime('now')),
('model-mistral-codestral-embed-2505-embedding', 'codestral-embed-2505', 'mistral', 'embedding', datetime('now'), datetime('now')),
('model-mistral-mistral-embed-embedding', 'mistral-embed', 'mistral', 'embedding', datetime('now'), datetime('now')),
('model-mistral-mistral-embed-2312-embedding', 'mistral-embed-2312', 'mistral', 'embedding', datetime('now'), datetime('now')),
('model-mistral-mistral-ocr-2512-embedding', 'mistral-ocr-2512', 'mistral', 'embedding', datetime('now'), datetime('now')),
('model-mistral-mistral-ocr-4-embedding', 'mistral-ocr-4', 'mistral', 'embedding', datetime('now'), datetime('now')),
('model-mistral-mistral-ocr-4-0-embedding', 'mistral-ocr-4-0', 'mistral', 'embedding', datetime('now'), datetime('now')),
('model-mistral-mistral-ocr-latest-embedding', 'mistral-ocr-latest', 'mistral', 'embedding', datetime('now'), datetime('now')),
('model-mistral-voxtral-mini-2602-speech_to_text', 'voxtral-mini-2602', 'mistral', 'speech_to_text', datetime('now'), datetime('now')),
('model-mistral-voxtral-mini-realtime-2602-speech_to_text', 'voxtral-mini-realtime-2602', 'mistral', 'speech_to_text', datetime('now'), datetime('now')),
('model-mistral-voxtral-mini-realtime-latest-speech_to_text', 'voxtral-mini-realtime-latest', 'mistral', 'speech_to_text', datetime('now'), datetime('now')),
('model-mistral-voxtral-mini-transcribe-realtime-2602-speech_to_text', 'voxtral-mini-transcribe-realtime-2602', 'mistral', 'speech_to_text', datetime('now'), datetime('now')),
('model-mistral-voxtral-mini-tts-2603-text_to_speech', 'voxtral-mini-tts-2603', 'mistral', 'text_to_speech', datetime('now'), datetime('now')),
('model-mistral-voxtral-mini-tts-latest-text_to_speech', 'voxtral-mini-tts-latest', 'mistral', 'text_to_speech', datetime('now'), datetime('now')),
('model-mistral-codestral-embed-text_to_speech', 'codestral-embed', 'mistral', 'text_to_speech', datetime('now'), datetime('now')),
('model-mistral-codestral-embed-2505-text_to_speech', 'codestral-embed-2505', 'mistral', 'text_to_speech', datetime('now'), datetime('now')),
('model-mistral-codestral-latest-text_to_speech', 'codestral-latest', 'mistral', 'text_to_speech', datetime('now'), datetime('now')),
('model-mistral-devstral-latest-text_to_speech', 'devstral-latest', 'mistral', 'text_to_speech', datetime('now'), datetime('now')),
('model-mistral-mistral-embed-text_to_speech', 'mistral-embed', 'mistral', 'text_to_speech', datetime('now'), datetime('now')),
('model-mistral-mistral-large-latest-text_to_speech', 'mistral-large-latest', 'mistral', 'text_to_speech', datetime('now'), datetime('now')),
('model-mistral-voxtral-mini-realtime-latest-text_to_speech', 'voxtral-mini-realtime-latest', 'mistral', 'text_to_speech', datetime('now'), datetime('now')),
('model-mistral-voxtral-mini-transcribe-realtime-2602-text_to_speech', 'voxtral-mini-transcribe-realtime-2602', 'mistral', 'text_to_speech', datetime('now'), datetime('now'));

-- ============================================
-- Seed preinstalled speaker profiles
-- (same content as the original app)
-- ============================================
INSERT OR IGNORE INTO speaker_profiles (id, name, description, voice_model, speakers, created, updated) VALUES
('sp-business-panel', 'business_panel', 'Панель бизнес-анализа с различными точками зрения', 'model-mistral-voxtral-mini-tts-latest-text_to_speech', '[{"name":"Маркус Томпсон","voice_id":"echo","backstory":"Бывший консультант McKinsey, теперь советник по стартапам. Эксперт в области стратегического анализа и динамики рынка.","personality":"Стратегический мыслитель, ориентирующийся на данные, превосходный в определении ключевых идей и последствий","voice_model":"model-mistral-voxtral-mini-tts-latest-text_to_speech"},{"name":"Елена Васкес","voice_id":"shimmer","backstory":"Серийный предприниматель и инвестор. Основное внимание уделяется практической реализации и исполнению.","personality":"Ориентирован на действия, прагматичен, приносит опыт запуска и сосредоточенность на исполнении."},{"name":"Джонни Бинг","voice_id":"ash","backstory":"Ютуб-знаменитость и бизнес-магнат. Основное внимание уделяется практической реализации и исполнению.","personality":"Спорный, любит подвергать сомнению идеи и концепции. Он привносит свежий взгляд и всегда имеет что сказать."}]', datetime('now'), datetime('now')),
('sp-solo-expert', 'solo_expert', 'Единый эксперт по образовательному контенту', 'model-mistral-voxtral-mini-tts-latest-text_to_speech', '[{"name":"Профессор Сара Ким","voice_id":"nova","backstory":"Заслуженный профессор и исследователь. Обладает даром делать сложные темы доступными для широкой аудитории.","personality":"Терпеливый преподаватель, использует аналогии и примеры, шаг за шагом разбирает сложные понятия.","voice_model":"model-mistral-voxtral-mini-tts-latest-text_to_speech"}]', datetime('now'), datetime('now')),
('sp-tech-experts', 'tech_experts', 'Два технических эксперта для технических дискуссий', 'model-mistral-voxtral-mini-tts-latest-text_to_speech', '[{"name":"Доктор Алекс Чен","voice_id":"nova","backstory":"Старший исследователь искусственного интеллекта и бывший технический руководитель крупных компаний. Специализируется на обеспечении доступности сложных технических концепций.","personality":"Аналитический, коммуникабельный, задает уточняющие вопросы, чтобы глубже разобраться в технических деталях."},{"name":"Джейми Родригес","voice_id":"alloy","backstory":"Full-stack инженер и технологический предприниматель. Любит практические применения и реальные реализации.","personality":"Энтузиаст, практичный, отлично объясняет детали реализации и компромиссы."}]', datetime('now'), datetime('now'));

-- ============================================
-- Seed preinstalled episode profiles
-- (same content as the original app)
-- ============================================
INSERT OR IGNORE INTO episode_profiles (id, name, description, speaker_config, outline_llm, transcript_llm, language, default_briefing, num_segments, created, updated) VALUES
('ep-solo-expert', 'solo_expert', 'Один эксперт, объясняющий сложные темы', 'sp-solo-expert', 'model-mistral-mistral-large-latest-language', 'model-mistral-mistral-large-latest-language', 'ru-RU', 'Создайте образовательное объяснение предоставленного контента. Разбивайте сложные концепции на удобоваримые сегменты, используйте аналогии и примеры и сохраняйте увлекательный стиль преподавания.', 4, datetime('now'), datetime('now')),
('ep-business-analysis', 'business_analysis', 'Business-focused analysis and discussion', 'sp-business-panel', 'model-mistral-mistral-large-latest-language', 'model-mistral-mistral-large-latest-language', 'ru-RU', 'Проанализируйте предоставленный контент с точки зрения бизнеса. Обсудите последствия для рынка, стратегические идеи, конкурентные преимущества и действенную бизнес-аналитику.', 6, datetime('now'), datetime('now')),
('ep-tech-discussion', 'tech_discussion', 'Техническая дискуссия между двумя экспертами', 'sp-tech-experts', 'model-mistral-mistral-large-latest-language', 'model-mistral-mistral-large-latest-language', 'ru-RU', 'Создайте увлекательное техническое обсуждение предоставленного контента. Сосредоточьтесь на практических выводах, реальных приложениях и подробных объяснениях, которые заинтересуют разработчиков и технических специалистов.', 5, datetime('now'), datetime('now'));
