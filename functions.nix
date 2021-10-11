{
  lists,
  strings,
  ...
}:
rec {
  keep-while = f: l:
    if lists.length l == 0
    then []
    else
      if !(f (lists.elemAt l 0))
      then [(lists.elemAt l 0)] ++ keep-while f (lists.tail l)
      else [];
  drop-while = f: l:
    if lists.length l == 0
    then []
    else
      if !(f (lists.elemAt l 0))
      then drop-while f (lists.tail l)
      else l;
  pairwise-uniq = l:
    let
      len = lists.length l;
      genList = f: n: if n >= 0 then lists.genList f n else [];
    in
      lists.concatLists
        (lists.genList (i: genList (j:
          { x = lists.elemAt l i;
            y = lists.elemAt l (j + i + 1);
          }
        ) (len - i - 1)) len);
  drop-ext = path:
    strings.concatStringsSep "." (lists.init (strings.splitString "." (filename-of path)));
  filename-of = path:
    lists.last (strings.splitString "/" (toString path));
  disjoint = l1: l2:
    builtins.length (lists.intersectLists l1 l2) == 0;
  tests = {
    keep-while = keep-while (x: x > 3) [1 2 3 4 6 2 1 15 1];
    drop-while = drop-while (x: x > 3) [1 2 3 4 6 2 1 15 1];
    pairwise-uniq = pairwise-uniq ["a" "b" "c" "d"];
    drop-ext = drop-ext "Hello.fst";
  };
}
