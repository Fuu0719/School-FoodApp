const message = '請輸入有效的台灣手機或含區碼市話，例如 0912345678、02-23456789；亦可留空';

function phone(value = '') {
  const invalid = () => Object.assign(new Error(message), { statusCode: 400 });
  if (typeof value !== 'string' || value.trim().length > 40) throw invalid();
  const input = value.trim();
  if (!input) return '';
  if (!/^(?:\+?[0-9]+(?:[ -][0-9]+)*|(?:\+886[ -]?)?\([0-9]{1,4}\)[ -]?[0-9]+(?:[ -][0-9]+)*)$/.test(input)) throw invalid();
  let number = input.replace(/[ ()-]/g, '');
  if (number.startsWith('+886')) number = `0${number.slice(4)}`;
  if (!/^(?:09[0-9]{8}|0[2-8][0-9]{7,8})$/.test(number)) throw invalid();
  return number;
}

module.exports = { phone };
