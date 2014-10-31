function connect() {
  /* connect to the mysql database */
  global $CONFIG;
  if (!$CONFIG['mysqlhost']) {
    $CONFIG['mysqlhost']   = "localhost";
    $CONFIG['mysqllogin']  = "root";
    $CONFIG['mysqlpass']   = "root";
    $CONFIG['mysqldb']     = "finalclub";
  }

  $CONFIG['sql'] = mysql_connect($CONFIG['mysqlhost'], $CONFIG['mysqllogin'], $CONFIG['mysqlpass']) or die("Error: Could not connect to SQL server.");

  mysql_select_db($CONFIG['mysqldb'], $CONFIG['sql']) or die("Error: Could not select SQL database for main site.");
}

function db_query($query) {
  $sql = mysql_query($query) or die(mysql_error());
  return $sql;
}

function get_content($section_id) {
  $content = '';
  $content_sql = db_query("SELECT `content` FROM `content` WHERE `section_id`='{$section_id}' LIMIT 1");
  if (mysql_num_rows($content_sql)) {
    $content = array_pop(mysql_fetch_row($content_sql));
  }
  return $content;
}

function get_content_magic_no() {
  return "####)(@*#)$*@!";
}

function prepare_content(&$content) {
  $magic_no = get_content_magic_no();
  $content = str_replace(array("<br />", ">", "</"), array("$magic_no ", "> ", " </"), $content);
}

function prepare_word(&$word) {
  $magic_no = get_content_magic_no();
  $word = trim(str_replace(array($magic_no, "<a>", "</a>"), array("<br />", "", ""), $word));
}

function get_words($content) {
  prepare_content($content);
  $words = explode(" ", $content);

  return $words;
}

function word_is_html($word) {
  return ($word[0] == '<' && $word[strlen($word)-1] == '>');
}

function generate_content($section_content, $page, &$words_raw) {

  switch ($page) {
    case "view-work":
    case "profile-annotations":
      $span = "style=\"background:#fff;\"";
      break;
    case "test":
    case "annotate":
      $span = "";
      break;

  }

  // separate content into words
  $words = get_words($section_content);
  $words_raw = array();
  $content = '';
  $i = 0;
  $can_print_with_span = true;
  foreach ($words as $word) {
    $add_br = false;
    $word = trim($word);
    if (!strlen($word)) continue;

    if (word_is_html($word)) {
      $content .= $word;
      continue;
    }

    $i++;
    prepare_word($word);
    $add_br = (strpos($word, "<br />") !== false);
    $word = str_replace("<br />", "", $word);

    // if this is the start of an html tag, but we don't have a closing tag, then don't print with span
    if ($word[0] == '<' && strpos($word, '>') === false) {
      $can_print_with_span = false;
      $html_started = true;
      $i-=2;
    }
    // in this case,
    elseif ($html_started && strpos($word, '>') === false) {
      $can_print_with_span = false;
      $i--;
    }
    // but, if a closing tag exists, add that to the span and recreate the word
    elseif (strpos($word, '>') !== false) {
      $content .= substr($word, 0, strpos($word, '>') + 1);
      $word = substr($word, strpos($word, '>') + 1, strlen($word));
      $can_print_with_span = true;
      $html_started = false;
    }

    if ($can_print_with_span) {
      if ($page == "annotate") {
        $content .= "<span id=\"word_$i\" onclick=\"handle_selection($i);\" onmouseover=\"word_highlight('word_$i');\" onmouseout=\"unword_highlight('word_$i');\">{$word} </span>";
      }
      elseif ($page == "view-work") {
        $content .= "<span id=\"word_$i\">{$word} </span>";
      }
      $words_raw[$i] = $word;
    }
    else {
      $content .= "{$word} ";
    }

    if ($add_br) {
      $content .= "<br />";
      $words_raw[$i] .= " <br />";
    }
  }

  return $content;
}

// don't care
error_reporting(0);

connect();

$content = get_content($section_id);

// separate content into words
$words_raw = array();
$content = generate_content($content, "view-work", $words_raw);
