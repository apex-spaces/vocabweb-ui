-- ============================================================================
-- 单词本网站 - PostgreSQL 数据库 DDL
-- 技术栈：Supabase (PostgreSQL 15+)
-- 功能：用户管理、单词收集、分组/标签、SM-2复习算法、学习统计
-- ============================================================================

-- ============================================================================
-- 第一部分：基础表结构
-- ============================================================================

-- 1. 用户扩展信息表
-- 关联 Supabase auth.users，存储用户偏好设置
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    username TEXT UNIQUE,
    display_name TEXT,
    avatar_url TEXT,
    timezone TEXT DEFAULT 'UTC',
    daily_review_goal INTEGER DEFAULT 20, -- 每日复习目标数量
    notification_enabled BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE public.profiles IS '用户扩展信息表';
COMMENT ON COLUMN public.profiles.daily_review_goal IS '每日复习目标单词数';

-- 2. 全局单词库
-- 存储所有单词的基础信息，多用户共享
CREATE TABLE IF NOT EXISTS public.words (
    id BIGSERIAL PRIMARY KEY,
    word TEXT NOT NULL UNIQUE, -- 单词本身（小写）
    phonetic_us TEXT, -- 美式音标
    phonetic_uk TEXT, -- 英式音标
    definitions JSONB NOT NULL DEFAULT '[]', -- 释义数组 [{pos: "n.", meaning: "...", example: "..."}]
    audio_us_url TEXT, -- 美式发音URL
    audio_uk_url TEXT, -- 英式发音URL
    frequency_rank INTEGER, -- 词频排名
    difficulty_level TEXT CHECK (difficulty_level IN ('beginner', 'intermediate', 'advanced', 'expert')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE public.words IS '全局单词库（多用户共享）';
COMMENT ON COLUMN public.words.definitions IS 'JSON数组：[{pos: "词性", meaning: "释义", example: "例句"}]';

CREATE INDEX idx_words_word ON public.words(word);
CREATE INDEX idx_words_frequency ON public.words(frequency_rank) WHERE frequency_rank IS NOT NULL;
CREATE INDEX idx_words_difficulty ON public.words(difficulty_level) WHERE difficulty_level IS NOT NULL;

-- 3. 用户自定义分组
CREATE TABLE IF NOT EXISTS public.groups (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    color TEXT, -- 分组颜色标识
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, name)
);

COMMENT ON TABLE public.groups IS '用户自定义单词分组';

CREATE INDEX idx_groups_user_id ON public.groups(user_id);
CREATE INDEX idx_groups_user_sort ON public.groups(user_id, sort_order);

-- 4. 用户自定义标签
CREATE TABLE IF NOT EXISTS public.tags (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    color TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, name)
);

COMMENT ON TABLE public.tags IS '用户自定义标签';

CREATE INDEX idx_tags_user_id ON public.tags(user_id);

-- 5. 用户-单词关系表（核心表）
-- 记录用户收藏的单词及其学习状态
CREATE TABLE IF NOT EXISTS public.user_words (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    word_id BIGINT NOT NULL REFERENCES public.words(id) ON DELETE CASCADE,
    group_id BIGINT REFERENCES public.groups(id) ON DELETE SET NULL,
    source_url TEXT, -- 收藏来源URL
    source_context TEXT, -- 来源上下文（原句）
    user_note TEXT, -- 用户笔记
    mastery_level INTEGER DEFAULT 0 CHECK (mastery_level >= 0 AND mastery_level <= 5), -- 掌握程度 0-5
    is_mastered BOOLEAN DEFAULT false, -- 是否已掌握
    collected_at TIMESTAMPTZ DEFAULT NOW(), -- 收藏时间
    last_reviewed_at TIMESTAMPTZ, -- 最后复习时间
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, word_id)
);

COMMENT ON TABLE public.user_words IS '用户-单词关系表（收藏、学习状态）';
COMMENT ON COLUMN public.user_words.source_url IS '收藏来源URL（网页、文章等）';
COMMENT ON COLUMN public.user_words.source_context IS '单词出现的原句上下文';
COMMENT ON COLUMN public.user_words.mastery_level IS '掌握程度 0-5级';

CREATE INDEX idx_user_words_user_id ON public.user_words(user_id);
CREATE INDEX idx_user_words_word_id ON public.user_words(word_id);
CREATE INDEX idx_user_words_group_id ON public.user_words(group_id) WHERE group_id IS NOT NULL;
CREATE INDEX idx_user_words_user_mastery ON public.user_words(user_id, mastery_level);
CREATE INDEX idx_user_words_user_collected ON public.user_words(user_id, collected_at DESC);

-- 6. 单词-标签多对多关系表
CREATE TABLE IF NOT EXISTS public.user_word_tags (
    id BIGSERIAL PRIMARY KEY,
    user_word_id BIGINT NOT NULL REFERENCES public.user_words(id) ON DELETE CASCADE,
    tag_id BIGINT NOT NULL REFERENCES public.tags(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_word_id, tag_id)
);

COMMENT ON TABLE public.user_word_tags IS '单词-标签多对多关系表';

CREATE INDEX idx_user_word_tags_user_word ON public.user_word_tags(user_word_id);
CREATE INDEX idx_user_word_tags_tag ON public.user_word_tags(tag_id);

-- 7. 复习记录表（SM-2算法核心）
-- 记录每次复习的详细信息和算法参数
CREATE TABLE IF NOT EXISTS public.review_logs (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    user_word_id BIGINT NOT NULL REFERENCES public.user_words(id) ON DELETE CASCADE,
    
    -- SM-2 算法参数
    quality INTEGER NOT NULL CHECK (quality >= 0 AND quality <= 5), -- 回答质量 0-5
    easiness_factor NUMERIC(4,2) NOT NULL DEFAULT 2.5, -- 难度因子 (1.3-2.5)
    interval INTEGER NOT NULL DEFAULT 0, -- 复习间隔（天）
    repetitions INTEGER NOT NULL DEFAULT 0, -- 连续正确次数
    next_review_at TIMESTAMPTZ NOT NULL, -- 下次复习时间
    
    -- 复习详情
    review_type TEXT CHECK (review_type IN ('new', 'review', 'relearn')), -- 复习类型
    time_spent_seconds INTEGER, -- 复习耗时（秒）
    reviewed_at TIMESTAMPTZ DEFAULT NOW(),
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE public.review_logs IS '复习记录表（SM-2算法）';
COMMENT ON COLUMN public.review_logs.quality IS 'SM-2质量评分：0=完全忘记, 3=勉强记起, 5=完美回忆';
COMMENT ON COLUMN public.review_logs.easiness_factor IS 'SM-2难度因子（1.3-2.5）';
COMMENT ON COLUMN public.review_logs.interval IS '下次复习间隔天数';
COMMENT ON COLUMN public.review_logs.repetitions IS '连续正确复习次数';

CREATE INDEX idx_review_logs_user_id ON public.review_logs(user_id);
CREATE INDEX idx_review_logs_user_word ON public.review_logs(user_word_id);
CREATE INDEX idx_review_logs_next_review ON public.review_logs(user_id, next_review_at);
CREATE INDEX idx_review_logs_reviewed_at ON public.review_logs(user_id, reviewed_at DESC);

-- 8. 每日学习统计表
-- 快照式存储每日学习数据
CREATE TABLE IF NOT EXISTS public.daily_stats (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    stat_date DATE NOT NULL,
    
    -- 学习统计
    new_words_count INTEGER DEFAULT 0, -- 新学单词数
    reviewed_words_count INTEGER DEFAULT 0, -- 复习单词数
    mastered_words_count INTEGER DEFAULT 0, -- 掌握单词数
    total_study_time_seconds INTEGER DEFAULT 0, -- 总学习时长（秒）
    
    -- 复习质量统计
    perfect_reviews INTEGER DEFAULT 0, -- 完美回忆次数 (quality=5)
    good_reviews INTEGER DEFAULT 0, -- 良好回忆 (quality=4)
    fair_reviews INTEGER DEFAULT 0, -- 一般回忆 (quality=3)
    poor_reviews INTEGER DEFAULT 0, -- 较差回忆 (quality<3)
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(user_id, stat_date)
);

COMMENT ON TABLE public.daily_stats IS '每日学习统计快照';

CREATE INDEX idx_daily_stats_user_date ON public.daily_stats(user_id, stat_date DESC);
CREATE INDEX idx_daily_stats_date ON public.daily_stats(stat_date DESC);

-- ============================================================================
-- 第二部分：触发器和函数
-- ============================================================================

-- 1. 自动更新 updated_at 字段的函数
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION public.update_updated_at_column IS '自动更新 updated_at 时间戳';

-- 为需要的表添加 updated_at 触发器
CREATE TRIGGER update_profiles_updated_at
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_words_updated_at
    BEFORE UPDATE ON public.words
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_groups_updated_at
    BEFORE UPDATE ON public.groups
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_user_words_updated_at
    BEFORE UPDATE ON public.user_words
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_daily_stats_updated_at
    BEFORE UPDATE ON public.daily_stats
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

-- 2. SM-2 算法计算函数
-- 根据回答质量计算下次复习时间和参数
CREATE OR REPLACE FUNCTION public.calculate_sm2_parameters(
    p_quality INTEGER,
    p_easiness_factor NUMERIC DEFAULT 2.5,
    p_interval INTEGER DEFAULT 0,
    p_repetitions INTEGER DEFAULT 0
)
RETURNS TABLE (
    new_easiness_factor NUMERIC,
    new_interval INTEGER,
    new_repetitions INTEGER,
    next_review_at TIMESTAMPTZ
) AS $$
DECLARE
    v_ef NUMERIC;
    v_interval INTEGER;
    v_reps INTEGER;
BEGIN
    -- SM-2 算法实现
    -- 更新难度因子 EF
    v_ef := p_easiness_factor + (0.1 - (5 - p_quality) * (0.08 + (5 - p_quality) * 0.02));
    
    -- EF 最小值为 1.3
    IF v_ef < 1.3 THEN
        v_ef := 1.3;
    END IF;
    
    -- 根据质量更新间隔和重复次数
    IF p_quality < 3 THEN
        -- 回答质量差，重新开始
        v_reps := 0;
        v_interval := 1;
    ELSE
        -- 回答质量好
        v_reps := p_repetitions + 1;
        
        IF v_reps = 1 THEN
            v_interval := 1;
        ELSIF v_reps = 2 THEN
            v_interval := 6;
        ELSE
            v_interval := ROUND(p_interval * v_ef)::INTEGER;
        END IF;
    END IF;
    
    -- 返回计算结果
    RETURN QUERY SELECT
        v_ef,
        v_interval,
        v_reps,
        (NOW() + (v_interval || ' days')::INTERVAL)::TIMESTAMPTZ;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION public.calculate_sm2_parameters IS 'SM-2算法：根据回答质量计算复习参数';

-- 3. 提交复习结果函数
-- 自动计算 SM-2 参数并更新相关表
CREATE OR REPLACE FUNCTION public.submit_review(
    p_user_id UUID,
    p_user_word_id BIGINT,
    p_quality INTEGER,
    p_time_spent_seconds INTEGER DEFAULT NULL
)
RETURNS BIGINT AS $$
DECLARE
    v_review_log_id BIGINT;
    v_current_ef NUMERIC;
    v_current_interval INTEGER;
    v_current_reps INTEGER;
    v_sm2_result RECORD;
BEGIN
    -- 获取当前 SM-2 参数（从最近一次复习记录）
    SELECT 
        COALESCE(easiness_factor, 2.5),
        COALESCE(interval, 0),
        COALESCE(repetitions, 0)
    INTO v_current_ef, v_current_interval, v_current_reps
    FROM public.review_logs
    WHERE user_word_id = p_user_word_id
    ORDER BY reviewed_at DESC
    LIMIT 1;
    
    -- 如果没有历史记录，使用默认值
    IF NOT FOUND THEN
        v_current_ef := 2.5;
        v_current_interval := 0;
        v_current_reps := 0;
    END IF;
    
    -- 计算新的 SM-2 参数
    SELECT * INTO v_sm2_result
    FROM public.calculate_sm2_parameters(
        p_quality,
        v_current_ef,
        v_current_interval,
        v_current_reps
    );
    
    -- 插入复习记录
    INSERT INTO public.review_logs (
        user_id,
        user_word_id,
        quality,
        easiness_factor,
        interval,
        repetitions,
        next_review_at,
        review_type,
        time_spent_seconds
    ) VALUES (
        p_user_id,
        p_user_word_id,
        p_quality,
        v_sm2_result.new_easiness_factor,
        v_sm2_result.new_interval,
        v_sm2_result.new_repetitions,
        v_sm2_result.next_review_at,
        CASE 
            WHEN v_current_reps = 0 THEN 'new'
            WHEN p_quality < 3 THEN 'relearn'
            ELSE 'review'
        END,
        p_time_spent_seconds
    ) RETURNING id INTO v_review_log_id;
    
    -- 更新 user_words 表
    UPDATE public.user_words
    SET 
        last_reviewed_at = NOW(),
        mastery_level = CASE
            WHEN v_sm2_result.new_repetitions >= 5 THEN 5
            WHEN v_sm2_result.new_repetitions >= 4 THEN 4
            WHEN v_sm2_result.new_repetitions >= 3 THEN 3
            WHEN v_sm2_result.new_repetitions >= 2 THEN 2
            WHEN v_sm2_result.new_repetitions >= 1 THEN 1
            ELSE 0
        END,
        is_mastered = (v_sm2_result.new_repetitions >= 5)
    WHERE id = p_user_word_id;
    
    RETURN v_review_log_id;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION public.submit_review IS '提交复习结果，自动计算SM-2参数并更新状态';

-- 4. 更新每日统计函数
-- 根据复习记录更新当日统计数据
CREATE OR REPLACE FUNCTION public.update_daily_stats(
    p_user_id UUID,
    p_stat_date DATE DEFAULT CURRENT_DATE
)
RETURNS VOID AS $$
BEGIN
    INSERT INTO public.daily_stats (
        user_id,
        stat_date,
        new_words_count,
        reviewed_words_count,
        mastered_words_count,
        total_study_time_seconds,
        perfect_reviews,
        good_reviews,
        fair_reviews,
        poor_reviews
    )
    SELECT
        p_user_id,
        p_stat_date,
        COUNT(DISTINCT CASE WHEN rl.review_type = 'new' THEN rl.user_word_id END),
        COUNT(DISTINCT rl.user_word_id),
        COUNT(DISTINCT CASE WHEN uw.is_mastered THEN uw.id END),
        COALESCE(SUM(rl.time_spent_seconds), 0),
        COUNT(CASE WHEN rl.quality = 5 THEN 1 END),
        COUNT(CASE WHEN rl.quality = 4 THEN 1 END),
        COUNT(CASE WHEN rl.quality = 3 THEN 1 END),
        COUNT(CASE WHEN rl.quality < 3 THEN 1 END)
    FROM public.review_logs rl
    LEFT JOIN public.user_words uw ON rl.user_word_id = uw.id
    WHERE rl.user_id = p_user_id
        AND DATE(rl.reviewed_at) = p_stat_date
    ON CONFLICT (user_id, stat_date)
    DO UPDATE SET
        new_words_count = EXCLUDED.new_words_count,
        reviewed_words_count = EXCLUDED.reviewed_words_count,
        mastered_words_count = EXCLUDED.mastered_words_count,
        total_study_time_seconds = EXCLUDED.total_study_time_seconds,
        perfect_reviews = EXCLUDED.perfect_reviews,
        good_reviews = EXCLUDED.good_reviews,
        fair_reviews = EXCLUDED.fair_reviews,
        poor_reviews = EXCLUDED.poor_reviews,
        updated_at = NOW();
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION public.update_daily_stats IS '更新指定日期的每日学习统计';

-- 5. 复习后自动更新统计的触发器函数
CREATE OR REPLACE FUNCTION public.trigger_update_daily_stats()
RETURNS TRIGGER AS $$
BEGIN
    PERFORM public.update_daily_stats(NEW.user_id, DATE(NEW.reviewed_at));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 为 review_logs 添加触发器
CREATE TRIGGER after_review_update_stats
    AFTER INSERT ON public.review_logs
    FOR EACH ROW
    EXECUTE FUNCTION public.trigger_update_daily_stats();

COMMENT ON TRIGGER after_review_update_stats ON public.review_logs IS '复习后自动更新每日统计';

-- 6. 获取待复习单词列表函数
CREATE OR REPLACE FUNCTION public.get_due_reviews(
    p_user_id UUID,
    p_limit INTEGER DEFAULT 20
)
RETURNS TABLE (
    user_word_id BIGINT,
    word TEXT,
    definitions JSONB,
    next_review_at TIMESTAMPTZ,
    mastery_level INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        uw.id,
        w.word,
        w.definitions,
        COALESCE(rl.next_review_at, uw.collected_at) as next_review_at,
        uw.mastery_level
    FROM public.user_words uw
    JOIN public.words w ON uw.word_id = w.id
    LEFT JOIN LATERAL (
        SELECT next_review_at
        FROM public.review_logs
        WHERE user_word_id = uw.id
        ORDER BY reviewed_at DESC
        LIMIT 1
    ) rl ON true
    WHERE uw.user_id = p_user_id
        AND uw.is_mastered = false
        AND COALESCE(rl.next_review_at, uw.collected_at) <= NOW()
    ORDER BY COALESCE(rl.next_review_at, uw.collected_at) ASC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION public.get_due_reviews IS '获取用户待复习的单词列表';

-- ============================================================================
-- 第三部分：Row Level Security (RLS) 策略
-- ============================================================================

-- 启用 RLS
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_words ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_word_tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.review_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_stats ENABLE ROW LEVEL SECURITY;

-- words 表为全局共享，所有人可读，管理员可写
ALTER TABLE public.words ENABLE ROW LEVEL SECURITY;

-- 1. profiles 表 RLS 策略
CREATE POLICY "Users can view own profile"
    ON public.profiles FOR SELECT
    USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
    ON public.profiles FOR UPDATE
    USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile"
    ON public.profiles FOR INSERT
    WITH CHECK (auth.uid() = id);

-- 2. words 表 RLS 策略（全局共享）
CREATE POLICY "Anyone can view words"
    ON public.words FOR SELECT
    USING (true);

CREATE POLICY "Only admins can modify words"
    ON public.words FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE id = auth.uid()
            AND (username = 'admin' OR display_name = 'admin')
        )
    );

-- 3. groups 表 RLS 策略
CREATE POLICY "Users can view own groups"
    ON public.groups FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own groups"
    ON public.groups FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own groups"
    ON public.groups FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own groups"
    ON public.groups FOR DELETE
    USING (auth.uid() = user_id);

-- 4. tags 表 RLS 策略
CREATE POLICY "Users can view own tags"
    ON public.tags FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own tags"
    ON public.tags FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own tags"
    ON public.tags FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own tags"
    ON public.tags FOR DELETE
    USING (auth.uid() = user_id);

-- 5. user_words 表 RLS 策略
CREATE POLICY "Users can view own words"
    ON public.user_words FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own words"
    ON public.user_words FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own words"
    ON public.user_words FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own words"
    ON public.user_words FOR DELETE
    USING (auth.uid() = user_id);

-- 6. user_word_tags 表 RLS 策略
CREATE POLICY "Users can view own word tags"
    ON public.user_word_tags FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.user_words
            WHERE id = user_word_tags.user_word_id
            AND user_id = auth.uid()
        )
    );

CREATE POLICY "Users can insert own word tags"
    ON public.user_word_tags FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.user_words
            WHERE id = user_word_tags.user_word_id
            AND user_id = auth.uid()
        )
    );

CREATE POLICY "Users can delete own word tags"
    ON public.user_word_tags FOR DELETE
    USING (
        EXISTS (
            SELECT 1 FROM public.user_words
            WHERE id = user_word_tags.user_word_id
            AND user_id = auth.uid()
        )
    );

-- 7. review_logs 表 RLS 策略
CREATE POLICY "Users can view own review logs"
    ON public.review_logs FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own review logs"
    ON public.review_logs FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- 8. daily_stats 表 RLS 策略
CREATE POLICY "Users can view own daily stats"
    ON public.daily_stats FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own daily stats"
    ON public.daily_stats FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own daily stats"
    ON public.daily_stats FOR UPDATE
    USING (auth.uid() = user_id);

-- ============================================================================
-- 第四部分：种子数据
-- ============================================================================

-- 1. 基础词库示例数据
-- 插入常用高频词汇
INSERT INTO public.words (word, phonetic_us, phonetic_uk, definitions, frequency_rank, difficulty_level) VALUES
('hello', '/həˈloʊ/', '/həˈləʊ/', 
 '[{"pos": "interj.", "meaning": "你好；喂", "example": "Hello, how are you?"}]'::jsonb,
 1, 'beginner'),

('world', '/wɜːrld/', '/wɜːld/', 
 '[{"pos": "n.", "meaning": "世界；地球", "example": "The world is a beautiful place."}]'::jsonb,
 2, 'beginner'),

('learn', '/lɜːrn/', '/lɜːn/', 
 '[{"pos": "v.", "meaning": "学习；学会", "example": "I want to learn English."}]'::jsonb,
 3, 'beginner'),

('vocabulary', '/voʊˈkæbjəleri/', '/vəˈkæbjələri/', 
 '[{"pos": "n.", "meaning": "词汇；词汇量", "example": "Building vocabulary is important for language learning."}]'::jsonb,
 150, 'intermediate'),

('algorithm', '/ˈælɡərɪðəm/', '/ˈælɡərɪðəm/', 
 '[{"pos": "n.", "meaning": "算法", "example": "The SM-2 algorithm is used for spaced repetition."}]'::jsonb,
 500, 'advanced'),

('ephemeral', '/ɪˈfemərəl/', '/ɪˈfemərəl/', 
 '[{"pos": "adj.", "meaning": "短暂的；瞬息的", "example": "The beauty of cherry blossoms is ephemeral."}]'::jsonb,
 2000, 'expert'),

('serendipity', '/ˌserənˈdɪpəti/', '/ˌserənˈdɪpəti/', 
 '[{"pos": "n.", "meaning": "意外发现；机缘巧合", "example": "Meeting you here was pure serendipity."}]'::jsonb,
 3000, 'expert')
ON CONFLICT (word) DO NOTHING;

-- 2. 更多常用词汇
INSERT INTO public.words (word, phonetic_us, phonetic_uk, definitions, frequency_rank, difficulty_level) VALUES
('study', '/ˈstʌdi/', '/ˈstʌdi/', 
 '[{"pos": "v.", "meaning": "学习；研究", "example": "I study English every day."}, {"pos": "n.", "meaning": "学习；研究", "example": "The study of languages is fascinating."}]'::jsonb,
 10, 'beginner'),

('remember', '/rɪˈmembər/', '/rɪˈmembə(r)/', 
 '[{"pos": "v.", "meaning": "记得；记住", "example": "I can''t remember his name."}]'::jsonb,
 20, 'beginner'),

('practice', '/ˈpræktɪs/', '/ˈpræktɪs/', 
 '[{"pos": "n.", "meaning": "练习；实践", "example": "Practice makes perfect."}, {"pos": "v.", "meaning": "练习；实践", "example": "You need to practice speaking."}]'::jsonb,
 30, 'intermediate'),

('review', '/rɪˈvjuː/', '/rɪˈvjuː/', 
 '[{"pos": "v.", "meaning": "复习；回顾", "example": "Let''s review what we learned."}, {"pos": "n.", "meaning": "复习；评论", "example": "The book received good reviews."}]'::jsonb,
 40, 'intermediate'),

('comprehension', '/ˌkɑːmprɪˈhenʃn/', '/ˌkɒmprɪˈhenʃn/', 
 '[{"pos": "n.", "meaning": "理解；理解力", "example": "Reading comprehension is a key skill."}]'::jsonb,
 200, 'intermediate'),

('proficiency', '/prəˈfɪʃnsi/', '/prəˈfɪʃnsi/', 
 '[{"pos": "n.", "meaning": "熟练；精通", "example": "She has achieved proficiency in three languages."}]'::jsonb,
 800, 'advanced'),

('cognitive', '/ˈkɑːɡnətɪv/', '/ˈkɒɡnətɪv/', 
 '[{"pos": "adj.", "meaning": "认知的", "example": "Cognitive abilities improve with practice."}]'::jsonb,
 1000, 'advanced'),

('mnemonic', '/nɪˈmɑːnɪk/', '/nɪˈmɒnɪk/', 
 '[{"pos": "adj.", "meaning": "记忆的；助记的", "example": "Use mnemonic devices to remember vocabulary."}, {"pos": "n.", "meaning": "助记符", "example": "ROY G BIV is a mnemonic for rainbow colors."}]'::jsonb,
 5000, 'expert')
ON CONFLICT (word) DO NOTHING;

-- ============================================================================
-- 第五部分：使用说明和示例
-- ============================================================================

-- 使用示例 1：用户注册后创建 profile
-- INSERT INTO public.profiles (id, username, display_name)
-- VALUES (auth.uid(), 'john_doe', 'John Doe');

-- 使用示例 2：用户收藏单词
-- INSERT INTO public.user_words (user_id, word_id, source_url, source_context, group_id)
-- SELECT 
--     auth.uid(),
--     w.id,
--     'https://example.com/article',
--     'This is an example sentence with the word.',
--     g.id
-- FROM public.words w
-- LEFT JOIN public.groups g ON g.user_id = auth.uid() AND g.name = 'My Group'
-- WHERE w.word = 'algorithm';

-- 使用示例 3：提交复习结果（使用函数）
-- SELECT public.submit_review(
--     auth.uid(),              -- 用户ID
--     123,                     -- user_word_id
--     4,                       -- quality (0-5)
--     30                       -- time_spent_seconds
-- );

-- 使用示例 4：获取待复习单词
-- SELECT * FROM public.get_due_reviews(auth.uid(), 20);

-- 使用示例 5：查询用户学习统计
-- SELECT * FROM public.daily_stats
-- WHERE user_id = auth.uid()
-- ORDER BY stat_date DESC
-- LIMIT 30;



-- 使用示例 6：为单词添加标签
-- WITH new_tag AS (
--     INSERT INTO public.tags (user_id, name, color)
--     VALUES (auth.uid(), 'Important', '#FF5733')
--     ON CONFLICT (user_id, name) DO UPDATE SET color = EXCLUDED.color
--     RETURNING id
-- )
-- INSERT INTO public.user_word_tags (user_word_id, tag_id)
-- SELECT 123, id FROM new_tag
-- ON CONFLICT DO NOTHING;

-- 使用示例 7：查询用户的单词列表（带标签和分组）
-- SELECT 
--     uw.id,
--     w.word,
--     w.definitions,
--     g.name as group_name,
--     uw.mastery_level,
--     uw.source_url,
--     array_agg(t.name) as tags
-- FROM public.user_words uw
-- JOIN public.words w ON uw.word_id = w.id
-- LEFT JOIN public.groups g ON uw.group_id = g.id
-- LEFT JOIN public.user_word_tags uwt ON uw.id = uwt.user_word_id
-- LEFT JOIN public.tags t ON uwt.tag_id = t.id
-- WHERE uw.user_id = auth.uid()
-- GROUP BY uw.id, w.word, w.definitions, g.name, uw.mastery_level, uw.source_url
-- ORDER BY uw.collected_at DESC;

-- 使用示例 8：手动更新每日统计
-- SELECT public.update_daily_stats(auth.uid(), CURRENT_DATE);

-- ============================================================================
-- 部署说明
-- ============================================================================

-- 1. 在 Supabase 项目中执行此 SQL 文件
--    - 登录 Supabase Dashboard
--    - 进入 SQL Editor
--    - 粘贴并执行此文件

-- 2. 确保 Supabase Auth 已启用
--    - 在 Authentication 设置中启用所需的登录方式
--    - 配置邮箱验证、密码策略等

-- 3. 在应用中使用 Supabase 客户端
--    - 安装: npm install @supabase/supabase-js
--    - 初始化客户端并进行认证
--    - 所有数据访问会自动通过 RLS 策略进行权限控制

-- 4. 可选：配置 Realtime 订阅
--    - 在 Supabase Dashboard 中为需要的表启用 Realtime
--    - 实时监听单词收藏、复习记录等变化


-- ============================================================================
-- 性能优化建议
-- ============================================================================

-- 1. 定期清理旧的复习记录（保留最近 6 个月）
-- CREATE OR REPLACE FUNCTION public.cleanup_old_review_logs()
-- RETURNS void AS $$
-- BEGIN
--     DELETE FROM public.review_logs 
--     WHERE reviewed_at < NOW() - INTERVAL '6 months';
-- END;
-- $$ LANGUAGE plpgsql;

-- 2. 定期分析表以优化查询性能
-- ANALYZE public.user_words;
-- ANALYZE public.review_logs;
-- ANALYZE public.daily_stats;

-- 3. 监控慢查询（需要启用 pg_stat_statements 扩展）
-- CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
-- SELECT query, mean_exec_time, calls
-- FROM pg_stat_statements 
-- WHERE query LIKE '%user_words%' 
-- ORDER BY mean_exec_time DESC
-- LIMIT 10;

-- 4. 为高频查询创建物化视图（可选）
-- CREATE MATERIALIZED VIEW user_word_summary AS
-- SELECT 
--     uw.user_id,
--     COUNT(*) as total_words,
--     COUNT(*) FILTER (WHERE uw.is_mastered) as mastered_count,
--     AVG(uw.mastery_level) as avg_mastery
-- FROM public.user_words uw
-- GROUP BY uw.user_id;
-- 
-- CREATE UNIQUE INDEX ON user_word_summary (user_id);
-- 
-- -- 定期刷新物化视图
-- REFRESH MATERIALIZED VIEW CONCURRENTLY user_word_summary;


-- ============================================================================
-- 数据维护和备份
-- ============================================================================

-- 1. 备份用户数据（导出为 JSON）
-- SELECT json_agg(row_to_json(t))
-- FROM (
--     SELECT 
--         uw.*,
--         w.word,
--         w.definitions,
--         array_agg(DISTINCT t.name) as tags
--     FROM public.user_words uw
--     JOIN public.words w ON uw.word_id = w.id
--     LEFT JOIN public.user_word_tags uwt ON uw.id = uwt.user_word_id
--     LEFT JOIN public.tags t ON uwt.tag_id = t.id
--     WHERE uw.user_id = auth.uid()
--     GROUP BY uw.id, w.word, w.definitions
-- ) t;

-- 2. 数据完整性检查
-- -- 检查孤立的 user_words（没有对应的 word）
-- SELECT COUNT(*) FROM public.user_words uw
-- WHERE NOT EXISTS (SELECT 1 FROM public.words w WHERE w.id = uw.word_id);
-- 
-- -- 检查孤立的 review_logs
-- SELECT COUNT(*) FROM public.review_logs rl
-- WHERE NOT EXISTS (SELECT 1 FROM public.user_words uw WHERE uw.id = rl.user_word_id);

-- 3. 统计信息查询
-- -- 用户学习概览
-- SELECT 
--     COUNT(*) as total_words,
--     COUNT(*) FILTER (WHERE is_mastered) as mastered_words,
--     AVG(mastery_level) as avg_mastery,
--     COUNT(DISTINCT group_id) as total_groups
-- FROM public.user_words
-- WHERE user_id = auth.uid();


-- ============================================================================
-- 常见问题和最佳实践
-- ============================================================================

-- Q1: 如何批量导入单词？
-- A: 使用 COPY 命令或批量 INSERT
-- COPY public.words (word, phonetic_us, phonetic_uk, definitions, frequency_rank, difficulty_level)
-- FROM '/path/to/words.csv'
-- WITH (FORMAT csv, HEADER true);

-- Q2: 如何处理单词的多个释义？
-- A: definitions 字段使用 JSONB 数组存储，可以包含多个释义
-- UPDATE public.words
-- SET definitions = definitions || '[{"pos": "v.", "meaning": "新释义", "example": "例句"}]'::jsonb
-- WHERE word = 'example';

-- Q3: 如何调整 SM-2 算法参数？
-- A: 修改 calculate_sm2_parameters 函数中的系数
-- 当前实现：EF' = EF + (0.1 - (5-q) * (0.08 + (5-q) * 0.02))
-- 可以根据实际效果调整这些系数

-- Q4: 如何实现单词搜索？
-- A: 使用全文搜索或模糊匹配
-- -- 精确匹配
-- SELECT * FROM public.words WHERE word = 'hello';
-- 
-- -- 前缀匹配
-- SELECT * FROM public.words WHERE word LIKE 'hel%';
-- 
-- -- 全文搜索（需要创建 tsvector 索引）
-- CREATE INDEX idx_words_fts ON public.words 
-- USING gin(to_tsvector('english', word || ' ' || definitions::text));

-- Q5: 如何实现学习提醒？
-- A: 使用 Supabase Edge Functions + Cron Jobs
-- 或在应用层定期查询 get_due_reviews 函数


-- ============================================================================
-- 扩展功能建议
-- ============================================================================

-- 1. 添加单词发音音频表（如果需要存储自定义音频）
-- CREATE TABLE IF NOT EXISTS public.word_audio (
--     id BIGSERIAL PRIMARY KEY,
--     word_id BIGINT NOT NULL REFERENCES public.words(id) ON DELETE CASCADE,
--     audio_type TEXT CHECK (audio_type IN ('us', 'uk', 'custom')),
--     audio_url TEXT NOT NULL,
--     created_at TIMESTAMPTZ DEFAULT NOW()
-- );

-- 2. 添加学习笔记表（支持富文本）
-- CREATE TABLE IF NOT EXISTS public.study_notes (
--     id BIGSERIAL PRIMARY KEY,
--     user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
--     user_word_id BIGINT REFERENCES public.user_words(id) ON DELETE CASCADE,
--     title TEXT,
--     content TEXT NOT NULL,
--     note_type TEXT CHECK (note_type IN ('text', 'markdown', 'html')),
--     created_at TIMESTAMPTZ DEFAULT NOW(),
--     updated_at TIMESTAMPTZ DEFAULT NOW()
-- );

-- 3. 添加学习目标表
-- CREATE TABLE IF NOT EXISTS public.learning_goals (
--     id BIGSERIAL PRIMARY KEY,
--     user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
--     goal_type TEXT CHECK (goal_type IN ('daily', 'weekly', 'monthly')),
--     target_count INTEGER NOT NULL,
--     start_date DATE NOT NULL,
--     end_date DATE,
--     is_active BOOLEAN DEFAULT true,
--     created_at TIMESTAMPTZ DEFAULT NOW()
-- );

-- 4. 添加单词关联表（同义词、反义词等）
-- CREATE TABLE IF NOT EXISTS public.word_relations (
--     id BIGSERIAL PRIMARY KEY,
--     word_id BIGINT NOT NULL REFERENCES public.words(id) ON DELETE CASCADE,
--     related_word_id BIGINT NOT NULL REFERENCES public.words(id) ON DELETE CASCADE,
--     relation_type TEXT CHECK (relation_type IN ('synonym', 'antonym', 'derivative', 'related')),
--     created_at TIMESTAMPTZ DEFAULT NOW(),
--     UNIQUE(word_id, related_word_id, relation_type)
-- );


-- ============================================================================
-- API 使用示例（Supabase JavaScript 客户端）
-- ============================================================================

-- 示例 1：用户注册后创建 profile
-- const { data, error } = await supabase
--   .from('profiles')
--   .insert({
--     id: user.id,
--     username: 'john_doe',
--     display_name: 'John Doe'
--   });

-- 示例 2：收藏单词
-- const { data: word } = await supabase
--   .from('words')
--   .select('id')
--   .eq('word', 'algorithm')
--   .single();
-- 
-- const { data, error } = await supabase
--   .from('user_words')
--   .insert({
--     word_id: word.id,
--     source_url: 'https://example.com',
--     source_context: 'The algorithm is efficient.'
--   });

-- 示例 3：提交复习结果
-- const { data, error } = await supabase
--   .rpc('submit_review', {
--     p_user_id: user.id,
--     p_user_word_id: 123,
--     p_quality: 4,
--     p_time_spent_seconds: 30
--   });

-- 示例 4：获取待复习单词
-- const { data, error } = await supabase
--   .rpc('get_due_reviews', {
--     p_user_id: user.id,
--     p_limit: 20
--   });

-- 示例 5：查询学习统计
-- const { data, error } = await supabase
--   .from('daily_stats')
--   .select('*')
--   .order('stat_date', { ascending: false })
--   .limit(30);


-- ============================================================================
-- 安全注意事项
-- ============================================================================

-- 1. RLS 策略已启用，确保所有表都有适当的策略
-- 2. 敏感操作（如删除用户数据）应在应用层添加二次确认
-- 3. 定期审计 auth.users 和 profiles 的一致性
-- 4. 使用 Supabase 的 Service Role Key 时要特别小心（绕过 RLS）
-- 5. 生产环境建议启用数据库备份和 Point-in-Time Recovery

-- ============================================================================
-- 版本历史
-- ============================================================================

-- v1.0.0 (2026-02-07)
-- - 初始版本
-- - 基础表结构：profiles, words, user_words, groups, tags, user_word_tags
-- - SM-2 算法实现：review_logs, calculate_sm2_parameters, submit_review
-- - 学习统计：daily_stats, update_daily_stats
-- - RLS 策略完整实现
-- - 种子数据和使用示例

-- ============================================================================
-- 许可证和贡献
-- ============================================================================

-- 本数据库设计可自由使用和修改
-- 建议根据实际需求调整表结构和算法参数
-- 欢迎提出改进建议

-- ============================================================================
-- 联系方式和支持
-- ============================================================================

-- 如有问题或建议，请通过以下方式联系：
-- - GitHub Issues
-- - Supabase Community
-- - 项目文档

-- ============================================================================
-- 结束
-- ============================================================================

-- 数据库初始化完成！
-- 下一步：
-- 1. 在 Supabase Dashboard 执行此 SQL 文件
-- 2. 配置 Supabase Auth 认证方式
-- 3. 在应用中集成 Supabase 客户端
-- 4. 开始构建前端界面
-- 5. 测试 RLS 策略和 SM-2 算法

-- 祝你的单词本网站开发顺利！🚀
