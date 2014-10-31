-- 4

update sections set `order` = 1 where work_id = 4;
insert into sections (work_id, `order`, name) values (4, 0, 'Title page');
update content
join sections on sections.name = 'Title page' and sections.work_id = 4
set content.section_id = sections.id
where content.section_id = 10;

-- 17: https://archive.org/details/poetryandproseof030447mbp

update sections
set `order` = `order` + 1
where `order` >= 59 and work_id = 17;
update sections set `order` = 59 where id = 750;

-- 25

delete from content where section_id = 635;

-- 29, 823: https://archive.org/details/sacredwoodessays00elio

update section_parents set parent_id = 823 where child_id = 831;
update sections set name = 'The Sacred Wood: Essays on Poetry and Criticism, Tradition and the Individual Talent' where id = 831;

update section_parents set parent_id = 823 where child_id = 835;
update sections set name = 'The Sacred Wood: Essays on Poetry and Criticism, Notes on the Blank Verse of Christopher Marlowe' where id = 835;

-- 128: http://www.gutenberg.org/ebooks/3600

-- The numerous "volumes" in this work do not appear in the source material.
-- The source material is split up into one "letters" section and three "books".
-- I have left the volumes in place, just in case they actually were put there
-- for some purpose.

update sections set `order` = `order` + 1 where `order` >= 94 and work_id = 128;
insert into sections (work_id, `order`, name) values (128, 94, 'Volume X, Chapter VII: Of Recompenses of Honour');
update content
join sections on sections.name = 'Volume X, Chapter VII: Of Recompenses of Honour' and sections.work_id = 128
set content.section_id = sections.id
where content.section_id = 2990;

-- 130

delete from content where section_id = 3247;

-- 131

delete from content where section_id = 3124;

delete from content where section_id = 3144;

delete from content where section_id = 3156;

-- 132

delete from content where section_id = 3345;

-- 159

update sections set `order` = `order` + 1 where `order` >= 2 and work_id = 159;
insert into sections (work_id, `order`, name) values (159, 2, 'Introduction and Analysis, Part I');
update sections set name = 'Introduction and Analysis, Part II' where id = 3739;
update sections set name = 'Introduction and Analysis, Part III' where id = 3740;
update content
join sections on sections.name = 'Introduction and Analysis, Part I' and sections.work_id = 159
set content.section_id = sections.id
where content.section_id = 3738;

-- 161
-- todo

-- 216: http://www.gutenberg.org/ebooks/1322

update section_parents set parent_id = 9980 where child_id = 9983;
update sections set name = 'Chapter 19: Sea-Drift, Sea-Drift, As I Ebb\'d with the Ocean of Life, Part 3' where id = 9983;

update sections set `order` = 391 where id = 9689;
update sections set `order` = 392 where id = 9690;

insert into section_parents (parent_id, child_id) values (10185, 10190);
update sections set name = 'Chapter 32: From Noon to Starry Night, From Noon to Starry Night, The Mystic Trumpeter, Part 5' where id = 10190;

delete from content where section_id = 9474;

-- 292: http://www.gutenberg.org/ebooks/1023

update section_parents set parent_id = 10953 where child_id = 10954;
update sections set name = 'Bleak House, Bleak House, Chapter VI, Part 1' where id = 10954;

update section_parents set parent_id = 10957 where child_id = 10959;

delete from sections where id = 11023;
delete from content where section_id = 11023;
delete from section_parents where child_id = 11023;

update section_parents set parent_id = 11024 where child_id = 11025;
update sections set name = 'Bleak House, Bleak House, Chapter XXXIII, Part 1' where id = 11025;

delete from sections where id = 10981;
delete from section_parents where child_id = 10981;
delete from content where section_id = 10981;

delete from sections where id = 10980;
delete from section_parents where child_id = 10980;

delete from content where section_id = 10983;

update content set section_id = 10983 where section_id = 10980;

-- 296: http://www.gutenberg.org/ebooks/968

update section_parents set parent_id = 11402 where child_id = 11403;

delete from content where section_id = 11392;

update sections set `order` = `order` + 1 where `order` >= 100 and work_id = 296;
insert into sections (work_id, `order`, name) values (296, 100, 'Martin Chuzzlewit, Martin Chuzzlewit, Chapter 43');
insert into section_parents
select 11351, id from sections
where work_id = 296 and `order` = 100;

update section_parents
join sections on sections.name = 'Martin Chuzzlewit, Martin Chuzzlewit, Chapter 43' and sections.work_id = 296
set section_parents.parent_id = sections.id
where section_parents.parent_id = 11448;

update sections
set name = replace(name, 'Chapter 42', 'Chapter 43')
where name like 'Martin Chuzzlewit, Martin Chuzzlewit, Chapter 42, %';

-- 298, 10533: https://archive.org/details/celtictwilight00yeatgoog

insert into section_parents (parent_id, child_id)
select 10533, id
from sections
where name rlike '^The Celtic Twilight ?,' and
      (select count(*) from section_parents where child_id = id) = 0;

update sections
set name = replace(name, 'The Celtic Twilight ', 'The Celtic Twilight')
where name like 'The Celtic Twilight %';

-- 300: http://www.gutenberg.org/ebooks/883

update sections set name = 'The Cup and The Lip, The Cup and The Lip, Boffin&rsquo;s Bower,  - Part I' where id = 11602;
update sections set name = 'The Cup and The Lip, The Cup and The Lip, Boffin&rsquo;s Bower,  - Part II' where id = 11603;

update section_parents set parent_id = 11604 where child_id = 11605;
update sections set name = 'The Cup and The Lip, The Cup and The Lip, Cut Adrift,  - Part I' where id = 11605;

-- 302: https://archive.org/details/poemsofemilydick030097mbp

insert into section_parents (parent_id, child_id) values (11855, 13757);
update sections set name = 'Poetry, Glass was the Street &mdash; in tinsel Peril' where id = 13757;

update section_parents set parent_id = 11855 where child_id = 13796;

insert into section_parents (parent_id, child_id) values (11855, 13801);

-- 323: http://www.gutenberg.org/ebooks/228

insert into section_parents (parent_id, child_id)
select books.id, pages.id
from sections as pages
join sections as books on pages.name like concat(books.name, ' %')
where pages.work_id = 323;

update sections as pages
join section_parents on pages.id = section_parents.child_id
join sections as books on books.id = section_parents.parent_id
set pages.name = replace(pages.name, books.name, concat(books.name, ','))
where not exists (select * from section_parents where parent_id = pages.id) and
      pages.work_id = 323;

-- fix section headings with content todo

-- 325: http://en.wikisource.org/wiki/The_City_of_God

update section_parents set parent_id = 15090 where child_id = 15100;

update section_parents set parent_id = 15118 where child_id = 15148;
update sections set name = 'Book XVI, Chapter XXIX' where id = 15148;

update section_parents set parent_id = 15163 where child_id = 15185;

update section_parents set parent_id = 15188 where child_id = 15213;
update sections set name = 'Book XVIII, Chapter XXV' where id = 15213;

-- 327: http://www.gutenberg.org/ebooks/3300

insert into section_parents (parent_id, child_id) values (14677, 16062);

-- 334: ...

delete from section_parents where child_id in (15462, 15464, 15591);
update sections set name = replace(name, 'Politics, ', '') where id in (15462, 15464, 15591);

-- 348: http://www.gutenberg.org/ebooks/3726

update section_parents set parent_id = 15981 where child_id = 16002;

-- 358: chapters 5 duplicates 4
--      http://www.thefinalclub.org/view-work.php?work_id=358&section_id=17420
--      http://www.thefinalclub.org/view-work.php?work_id=358&section_id=17422

delete from sections where id = 17422;
delete from section_parents where child_id = 17422;
delete from content where section_id = 17422;

-- 362: https://archive.org/details/convivioofdantea00dantiala

delete from section_parents where child_id in (18017, 18058);
delete from sections where id = 17980;
delete from content where section_id = 17980;
update sections set name = replace(name, 'Convivio, ', '') where work_id = 362;
update sections set name = replace(name, 'IV,', '') where work_id = 362;
update sections set name = replace(name, 'III,', '') where work_id = 362;
update sections set name = replace(name, 'II,', '') where work_id = 362;
update sections set name = replace(name, 'I,', '') where work_id = 362;

-- 371: http://alighieri.letteraturaoperaomnia.org/translate_english/alighieri_dante_de_vulgari_eloquentia.html

update section_parents
join sections on section_parents.child_id = sections.id
set section_parents.parent_id = 18111
where sections.name rlike '^De vulgari eloquentia,  ?I, ';

update sections
set name = replace(name, 'De vulgari eloquentia, I, ', 'Liber primus, ')
where name like 'De vulgari eloquentia, I, %';

update sections
set name = replace(name, 'De vulgari eloquentia,  I, ', 'Liber primus, ')
where name like 'De vulgari eloquentia,  I, %';

update section_parents
join sections on section_parents.child_id = sections.id
set section_parents.parent_id = 18112
where sections.name rlike '^De vulgari eloquentia,  ?II, ';

update sections
set name = replace(name, 'De vulgari eloquentia, II, ', 'Liber secundus, ')
where name like 'De vulgari eloquentia, II, %';

update sections
set name = replace(name, 'De vulgari eloquentia,  II, ', 'Liber secundus, ')
where name like 'De vulgari eloquentia,  II, %';

delete from sections where id = 18073;

-- 379

delete from content where section_id = 18297;
delete from content where section_id = 18304;

-- todo missing most of its chapters

-- 381

delete from content where section_id = 18320;
delete from content where section_id = 18324;
delete from content where section_id = 18326;
delete from content where section_id = 18328;
delete from content where section_id = 18329;

-- 386: http://www.gutenberg.org/ebooks/9662

insert into section_parents (parent_id, child_id) values (18595, 18613);
update sections set name = 'An Enquiry Concerning Human Understanding, Section XI-Of a particular Providence and of a future State-1' where id = 18613;

-- 387: http://www.gutenberg.org/ebooks/17611

insert into section_parents (parent_id, child_id) values (18611, 18619);
update section_parents set parent_id = 18611 where child_id = 18617;

-- fix encodings

--  fix utf8 in latin1 tables

alter table annotations convert to character set utf8;
alter table content convert to character set utf8;
alter table works convert to character set utf8;

update content set content = convert(binary convert(content using latin1) using utf8);

update content
join sections on content.section_id = sections.id
join works on sections.work_id = works.id
set content = convert(convert(binary replace(content, 0xc297, 0x97) using latin1) using utf8)
where works.id = 115;

update content
set content = replace(convert(convert(binary replace(content, 0xc292, 0x92) using latin1) using utf8),
                      'Channing-Cheetah\'',
                      'Channing-Cheetah')
where id = 683;

update annotations set annotation = convert(binary convert(annotation using latin1) using utf8),
                       quote      = convert(binary convert(quote      using latin1) using utf8);

update annotations
join sections on annotations.section_id = sections.id
join works on sections.work_id = works.id
set quote = convert(convert(binary replace(quote, 0xc297, 0x97) using latin1) using utf8)
where works.id = 115;

update works set summary     = convert(binary convert(summary     using latin1) using utf8),
                 intro_essay = convert(binary convert(intro_essay using latin1) using utf8)
             where id != 40;

--  fix double-encoded utf8 in utf8 tables

update annotation_links set reason = convert(binary convert(reason using latin1) using utf8);

update group_discussions set body = convert(binary convert(body using latin1) using utf8);

update library_users set subtitle = convert(binary convert(subtitle using latin1) using utf8),
                         content  = convert(binary convert(content using latin1) using utf8);
