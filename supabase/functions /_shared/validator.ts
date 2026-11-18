// Small, configurable whitelists (edit per level).
export const FUNCTION_WORDS = ["a","an","the","is","am","are","i","you","he","she","it","we","they","yes","no","and","or","not","my","your","this","that","what","can","do","have","like","with","to","of","in","on","please","hello","hi","bye","thanks","thank","i'm","it's","you're","that's","what's","let's","don't"];
export const PRAISE = ["good","great","nice","well","wow","super","try","again","say","job"];

const norm = (w: string) => w.toLowerCase().replace(/’/g, "'");
export const tokenize = (t: string) => (t.match(/[A-Za-z][A-Za-z'’]*/g) ?? []).map(norm);
// crude English inflection tolerance: plurals / possessive of allowed words
const forms = (t: string) => t.length < 4 ? [t] : [t, t.replace(/'s$/, ""), t.replace(/s$/, ""), t.replace(/es$/, ""), t.replace(/ies$/, "y")];

export function buildAllowed(lessonWords: string[], extra: string[] = []) {
  const s = new Set<string>();
  for (const w of [...lessonWords, ...extra, ...FUNCTION_WORDS, ...PRAISE]) tokenize(w).forEach((t) => s.add(t));
  return s;
}
/** Returns the out-of-list words found in `reply` (empty array = valid). */
export const findViolations = (reply: string, allowed: Set<string>) =>
  [...new Set(tokenize(reply).filter((t) => !forms(t).some((f) => allowed.has(f))))];
