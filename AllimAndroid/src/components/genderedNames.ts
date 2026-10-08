// Common first names that lean strongly one way, used only to pick which set
// of stand-in portraits someone without a photo is drawn from.
//
// Names that are commonly given to both (Alex, Jordan, Taylor, Jimin, Yuki,
// Jean, Wei…) are left out on purpose: they fall back to the whole set rather
// than guessing. Lowercase, ASCII, no hyphens — `portraits.ts` normalises the
// name the same way before looking it up.

const MALE = `
  aaron adam adrian aiden alan albert alejandro alessandro alexander alexei ali
  amit andres andrei andrew anil anthony antonio arjun arthur austin benjamin
  billy bjorn bobby boris brandon brian bruce bryan caleb carl carlos carter
  charles christian christopher colin connor daisuke daniel david dennis
  deepak diego dmitri dohyun dongwook donghyun donald douglas duc dylan eduardo
  edward elijah eric erik ethan eugene eunwoo evan felix fernando francesco
  francisco frank gabriel gang gary george gerald giovanni giuseppe grayson
  gregory guillaume hans harold haoran haruto hassan henry hiroshi hiroto
  hudson hugo hung hunter hussein hyunwoo ian ibrahim igor isaac isaiah ivan
  jack jackson jacob jacques jaehyun jaemin jaewon james jason javier jayden
  jeffrey jeremy jerry jesse jian jihoon jihun jinwoo john jonas jonathan
  joonho jorge jose joseph joshua juan julian junho junseo junyoung jurgen
  justin kaito karim kazuki keith kenji kenneth kenta kevin khalid klaus
  krishna kyle kyungsoo larry lars lawrence leo leon levi liam logan lorenzo
  louis luca lucas luis luke lukas manoj manuel marco mark mason mateo matteo
  matthew max maximilian michael miguel mikhail minho minjun minsoo mohamed
  mohammed moritz muhammad mustafa naoki nathan nicholas nicolas nikolai noah
  nolan olaf oleg oliver omar oscar owen pablo patrick paul pedro peng peter
  philip pierre qiang quang rafael raj ralph ramesh randy ravi raymond ricardo
  richard robert roberto roger rohan ronald roy russell ryan ryota samuel
  sangwoo sanjay satoshi scott sean sebastian seojun seungmin seunghyun sergei
  sergio shota siwoo sota stefan stephen steven sungmin sunil suresh sven
  taehyun taeyang takashi takeshi takumi tao tariq terry theodore thomas
  timothy tobias tuan tyler vijay vikram vincent vladimir walter wayne
  william willie wonjun woojin wyatt yejun youngho youngsoo yuri yusuf yuto
  zachary zihao
`;

const FEMALE = `
  abigail adriana aiko aisha akiko alejandra alessia alice amanda amber amelia
  amy ana ananya anastasia andrea angela anjali ann anna anne ashley astrid
  aurora ava ayaka barbara beatriz betty beverly brenda brittany camila
  camille carmen carol carolyn catherine chaewon chaeyoung charlotte cheryl
  chiara chloe christina christine claire cynthia dahyun daniela danielle
  deborah debra deepa denise diana diane divya donna doris dorothy ekaterina
  elena eleanor elizabeth ella emi emily emma eunbi eunhee eunji evelyn fang
  fatima federica fernanda frances francesca freya gabriela giulia gloria
  grace haeun hana hannah harper haruka hayoon hazel heather helen hoa huong
  hyejin hyuna hyunjoo ingrid irina isabel isabella jacqueline janet janice
  jennie jennifer jessica jieun jisoo jiyeon jiyoung joan joyce judith judy
  juliana julie kaori katarina katherine kathleen kathryn kavya kayla keiko
  kelly kimberly kyungmi lakshmi laura lauren layla lea leila lily linda lisa
  lori lucia lucy madison manon margaret maria mariana marie marilyn martha
  mary maryam mayumi megan mei melissa mia michelle mijin minji minseo misaki
  miyoung miyu monica nancy naomi natalie natasha nayeon neha nga nicole noor
  nora olga olivia pamela patricia paula pooja priya rachel rebecca rosa ruth
  sakura samantha sandra sara sarah seoa seoyeon seoyun seulgi sharon shirley
  sigrid silvia sofia sophia sophie soojin soyeon stella stephanie sujin
  sunhee sunita susan svetlana tatiana teresa theresa thuy trang valentina
  veronica victoria violet virginia xiu yasmin yejin yerin ying yoona
  younghee yui yuko yulia yumiko yuna zainab zoe zoey
`;

const toSet = (list: string) => new Set(list.trim().split(/\s+/));

export const MALE_NAMES = toSet(MALE);
export const FEMALE_NAMES = toSet(FEMALE);
