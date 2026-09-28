/**
 * cb-ja-search.js — Japanese (CJK) search support for CollectionBuilder
 *
 * Why this exists: lunr's default pipeline starts with lunr.trimmer, which
 * strips every leading/trailing non-\w character. Kanji and kana are all
 * non-\w, so every Japanese token is trimmed to the empty string and even an
 * exact title returns 0 results. This file adds:
 *
 *   1. cbJa.normalize(): NFKC, lowercase, katakana -> hiragana,
 *      kyujitai (old-form kanji) -> shinjitai (modern form), and the
 *      iteration mark 々 expanded, so 「圖」 matches 「図」, 「サクラ」 matches 「さくら」.
 *   2. A bigram tokenizer for CJK runs (Latin/number runs stay as words),
 *      so any substring of 2+ characters in a title can be found.
 *   3. cbJa.search(idx, query): runs the query with every bigram REQUIRED,
 *      which behaves like a substring search.
 *
 * Usage: load lunr.min.js, then this file, then build the index with
 * cbJa.buildIndex(fields, docs).
 *
 * License: MIT
 */
(function (global) {
  'use strict';

  // 旧字体 -> 新字体. Based on the 常用漢字表 parenthesised forms plus a few
  // frequent variants in bibliographic records. Keys are single characters.
  var KYU = '亞惡壓圍爲醫壹逸稻飮隱營榮衞驛謁圓鹽緣艷應歐毆櫻奧橫溫價禍悔海壞懷樂渴卷陷寬漢氣祈器僞戲虛峽狹響曉勤謹區驅勳薰徑惠揭溪經螢輕繼鷄藝擊缺儉劍圈檢權獻硏縣險顯驗嚴效廣恆鑛號國黑穀碎濟齋劑册雜參慘棧蠶贊殘祉絲視齒兒辭濕實舍寫煮社者釋壽收臭從澁獸縱祝肅處暑緖署諸敍將祥涉燒奬條狀乘淨剩疊孃讓釀觸寢愼眞神盡圖粹醉隨髓數樞瀨聲靜齊攝節專戰淺潛纖踐錢禪祖雙壯爭莊搜插巢曾僧層總騷增憎藏贈臟卽屬續墮體對帶滯臺瀧擇澤單嘆團斷彈晝鑄著廳徵聽懲鎭轉傳都嶋燈盜稻當黨德獨讀突屆難貳惱腦霸拜廢賣梅麥發髮拔繁晚蠻卑碑祕濱賓頻敏甁侮福拂佛倂塀竝變邊辨瓣辯步穗寶萠褒豐沒飜槇每萬滿免麵默餠戾彌譯藥與豫餘譽搖樣謠來賴亂欄覽龍兩獵綠淚壘類禮勵戾靈齡曆歷戀爐勞郞朗廊錄灣彎';
  var SHIN = '亜悪圧囲為医壱逸稲飲隠営栄衛駅謁円塩縁艶応欧殴桜奥横温価禍悔海壊懐楽渇巻陥寛漢気祈器偽戯虚峡狭響暁勤謹区駆勲薫径恵掲渓経蛍軽継鶏芸撃欠倹剣圏検権献研県険顕験厳効広恒鉱号国黒穀砕済斎剤冊雑参惨桟蚕賛残祉糸視歯児辞湿実舎写煮社者釈寿収臭従渋獣縦祝粛処暑緒署諸叙将祥渉焼奨条状乗浄剰畳嬢譲醸触寝慎真神尽図粋酔随髄数枢瀬声静斉摂節専戦浅潜繊践銭禅祖双壮争荘捜挿巣曽僧層総騒増憎蔵贈臓即属続堕体対帯滞台滝択沢単嘆団断弾昼鋳著庁徴聴懲鎮転伝都島灯盗稲当党徳独読突届難弐悩脳覇拝廃売梅麦発髪抜繁晩蛮卑碑秘浜賓頻敏瓶侮福払仏併塀並変辺弁弁弁歩穂宝萌褒豊没翻槙毎万満免麺黙餅戻弥訳薬与予余誉揺様謡来頼乱欄覧竜両猟緑涙塁類礼励戻霊齢暦歴恋炉労郎朗廊録湾湾';
  // A few characters that are not in the table above but are common in
  // pre-war titles and are unified to their modern form for searching.
  var EXTRA = {
    '學': '学', '會': '会', '圖': '図', '舊': '旧', '聯': '連', '冩': '写',
    '畫': '画', '臺': '台', '齋': '斎', '邊': '辺', '廣': '広', '藝': '芸',
    '莖': '茎', '蟲': '虫', '靑': '青', '淸': '清', '德': '徳', '徵': '徴',
    '眞': '真', '內': '内', '兩': '両', '卽': '即', '步': '歩', '拔': '抜',
    '黃': '黄', '姬': '姫', '缺': '欠', '豫': '予', '辨': '弁', '辯': '弁',
    '瓣': '弁', '竝': '並', '實': '実', '續': '続', '圓': '円', '櫻': '桜',
    '澤': '沢', '濱': '浜', '邉': '辺', '嶋': '島', '峯': '峰', '籐': '藤',
    '劍': '剣', '桒': '桑', '效': '効', '裝': '装', '將': '将', '壯': '壮',
    '莊': '荘', '狀': '状', '牀': '床', '鐵': '鉄', '顯': '顕', '濕': '湿',
    '絲': '糸', '變': '変', '戀': '恋', '蠻': '蛮', '灣': '湾', '彎': '湾',
    '稱': '称', '祕': '秘', '禮': '礼', '齒': '歯', '圍': '囲', '殼': '殻',
    '藏': '蔵', '寳': '宝', '寶': '宝', '甞': '嘗', '醫': '医', '藥': '薬',
    '樂': '楽', '爐': '炉', '螢': '蛍', '營': '営', '勞': '労', '榮': '栄',
    '參': '参', '廳': '庁', '傳': '伝', '轉': '転', '惠': '恵', '總': '総',
    '聰': '聡', '檢': '検', '驗': '験', '險': '険', '縣': '県', '縱': '縦',
    '萬': '万', '與': '与', '擧': '挙', '譽': '誉', '覺': '覚', '擴': '拡',
    '鑛': '鉱', '黨': '党', '當': '当'
  };
  var MAP = Object.create(null);
  (function () {
    var k = Array.from(KYU), s = Array.from(SHIN);
    for (var i = 0; i < k.length && i < s.length; i++) {
      if (k[i] !== s[i]) MAP[k[i]] = s[i];
    }
    Object.keys(EXTRA).forEach(function (key) {
      if (Array.from(key).length === 1 && key !== EXTRA[key]) MAP[key] = EXTRA[key];
    });
  })();

  function normalize(str) {
    if (str === null || str === undefined) return '';
    var s = String(str).normalize('NFKC').toLowerCase();
    var out = '';
    var prev = '';
    for (var ch of s) {
      var c = ch.codePointAt(0);
      // katakana -> hiragana (ァ..ヶ)
      if (c >= 0x30a1 && c <= 0x30f6) ch = String.fromCodePoint(c - 0x60);
      if (MAP[ch]) ch = MAP[ch];
      // iteration mark: 「佐々木」 -> 「佐佐木」
      if (ch === '々' && prev) ch = prev;
      out += ch;
      prev = ch;
    }
    return out;
  }

  // CJK ideographs, kana, iteration marks, and CJK compatibility ideographs
  var CJK = /[々〇぀-ゟ゠-ヿ㐀-䶿一-鿿豈-﫿\u{20000}-\u{2fa1f}]/u;
  // separators: whitespace and common punctuation (ASCII + Japanese)
  var SEP = /[\s　、。，．・：；！？「」『』（）()［］\[\]【】〈〉《》〔〕｛｝{}"'`,.:;!?\/\\|\-‐―－~〜=+*&%$#@^<>]+/u;

  // Split normalized text into tokens: CJK runs become bigrams (a lone CJK
  // character stays a unigram); other runs stay whole words. For indexing,
  // withUnigrams adds every single CJK character too, so one-character
  // queries (「竹」) and short runs between digits (「第1輯」) still match.
  function tokenize(text, withUnigrams) {
    var tokens = [];
    normalize(text).split(SEP).forEach(function (chunk) {
      if (!chunk) return;
      var run = '', isCjk = null;
      var flush = function () {
        if (!run) return;
        if (isCjk) {
          var chars = Array.from(run);
          if (chars.length === 1 || withUnigrams) chars.forEach(function (c) { tokens.push(c); });
          for (var i = 0; i < chars.length - 1; i++) tokens.push(chars[i] + chars[i + 1]);
        } else {
          tokens.push(run);
        }
        run = '';
      };
      for (var ch of chunk) {
        var c = CJK.test(ch);
        if (isCjk !== null && c !== isCjk) flush();
        isCjk = c;
        run += ch;
      }
      flush();
    });
    return tokens;
  }

  function lunrTokenizer(obj, metadata) {
    if (obj === null || obj === undefined) return [];
    if (Array.isArray(obj)) {
      return obj.map(function (t) { return new lunr.Token(normalize(t), lunr.utils.clone(metadata)); });
    }
    return tokenize(obj.toString(), true).map(function (t, i) {
      var md = lunr.utils.clone(metadata) || {};
      md.index = i;
      return new lunr.Token(t, md);
    });
  }

  function buildIndex(fields, docs) {
    return lunr(function () {
      // Replace the English-only pipeline (trimmer, stop words, stemmer).
      this.tokenizer = lunrTokenizer;
      this.pipeline.reset();
      this.searchPipeline.reset();
      this.ref('id');
      var builder = this;
      fields.forEach(function (f) { builder.field(f); });
      docs.forEach(function (doc, i) {
        var d = { id: String(i) };
        fields.forEach(function (f) { d[f] = doc[f]; });
        builder.add(d);
      });
    });
  }

  // Every token of the query is required: behaves like a substring search.
  function search(idx, query) {
    var terms = tokenize(query);
    if (!terms.length) return [];
    return idx.query(function (q) {
      terms.forEach(function (t) {
        q.term(t, { presence: lunr.Query.presence.REQUIRED });
      });
    });
  }

  // Plain substring test on normalized strings (used by the browse filter).
  function includes(haystack, needle) {
    return normalize(haystack).replace(/\s+/g, '').includes(normalize(needle).replace(/\s+/g, ''));
  }

  global.cbJa = { normalize: normalize, tokenize: tokenize, buildIndex: buildIndex, search: search, includes: includes };
})(typeof window !== 'undefined' ? window : globalThis);
