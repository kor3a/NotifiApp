import React from 'react';
import {StyleSheet, Text, TextStyle, View} from 'react-native';

// Renders the handful of markdown the recipe assistant writes — headings,
// bullets, numbered steps, paragraphs, and inline **bold** / *italic* — the
// same subset the iOS MarkdownTextView understands.

type Block =
  | {kind: 'h1' | 'h2' | 'h3' | 'bullet' | 'paragraph'; text: string}
  | {kind: 'numbered'; num: number; text: string}
  | {kind: 'spacer'};

function parseHeading(line: string): {level: number; text: string} | null {
  // "**### Ingredients**" still counts as a heading.
  let s = line;
  while (s.startsWith('**') && s.endsWith('**') && s.length > 4) {
    s = s.slice(2, -2).trim();
  }
  while (s.startsWith('*') && s.endsWith('*') && s.length > 2) {
    s = s.slice(1, -1).trim();
  }
  const match = /^(#+)\s*(.*?)\s*#*$/.exec(s);
  if (!match || !match[2]) {
    return null;
  }
  return {level: Math.min(match[1].length, 3), text: match[2]};
}

function parseBlocks(source: string): Block[] {
  const blocks: Block[] = [];
  let lastWasSpacer = true;
  for (const raw of source.split('\n')) {
    const line = raw.trim();
    if (!line) {
      if (!lastWasSpacer) {
        blocks.push({kind: 'spacer'});
        lastWasSpacer = true;
      }
      continue;
    }
    lastWasSpacer = false;
    const heading = parseHeading(line);
    const numbered = /^(\d+)\.\s*(.+)$/.exec(line);
    if (heading) {
      const kind = heading.level === 1 ? 'h1' : heading.level === 2 ? 'h2' : 'h3';
      blocks.push({kind, text: heading.text});
    } else if (line.startsWith('- ') || line.startsWith('* ')) {
      blocks.push({kind: 'bullet', text: line.slice(2)});
    } else if (numbered) {
      blocks.push({kind: 'numbered', num: Number(numbered[1]), text: numbered[2]});
    } else {
      blocks.push({kind: 'paragraph', text: line});
    }
  }
  if (blocks[blocks.length - 1]?.kind === 'spacer') {
    blocks.pop();
  }
  return blocks;
}

// **bold** and *italic* runs inside a line.
function Inline({text, style}: {text: string; style: TextStyle[]}) {
  const parts = text.split(/(\*\*[^*]+\*\*|\*[^*\s][^*]*\*)/g).filter(Boolean);
  return (
    <Text style={style}>
      {parts.map((part, i) => {
        if (part.startsWith('**') && part.endsWith('**') && part.length > 4) {
          return (
            <Text key={i} style={styles.bold}>
              {part.slice(2, -2)}
            </Text>
          );
        }
        if (part.startsWith('*') && part.endsWith('*') && part.length > 2) {
          return (
            <Text key={i} style={styles.italic}>
              {part.slice(1, -1)}
            </Text>
          );
        }
        return part;
      })}
    </Text>
  );
}

export default function MarkdownText({text, color}: {text: string; color: string}) {
  const base = {color};
  return (
    <View style={styles.container}>
      {parseBlocks(text).map((block, i) => {
        switch (block.kind) {
          case 'spacer':
            return <View key={i} style={styles.spacer} />;
          case 'h1':
          case 'h2':
          case 'h3':
            return <Inline key={i} text={block.text} style={[styles.body, base, styles[block.kind]]} />;
          case 'bullet':
            return (
              <View key={i} style={styles.listRow}>
                <Text style={[styles.body, base]}>•</Text>
                <Inline text={block.text} style={[styles.body, base, styles.listText]} />
              </View>
            );
          case 'numbered':
            return (
              <View key={i} style={styles.listRow}>
                <Text style={[styles.body, base, styles.number]}>{block.num}.</Text>
                <Inline text={block.text} style={[styles.body, base, styles.listText]} />
              </View>
            );
          default:
            return <Inline key={i} text={block.text} style={[styles.body, base]} />;
        }
      })}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    gap: 2,
  },
  body: {
    fontSize: 16,
    lineHeight: 22,
  },
  h1: {
    fontSize: 22,
    lineHeight: 28,
    fontWeight: '700',
    marginTop: 6,
  },
  h2: {
    fontSize: 20,
    lineHeight: 26,
    fontWeight: '700',
    marginTop: 4,
  },
  h3: {
    fontSize: 17,
    fontWeight: '700',
    marginTop: 4,
  },
  bold: {
    fontWeight: '700',
  },
  italic: {
    fontStyle: 'italic',
  },
  listRow: {
    flexDirection: 'row',
    gap: 6,
  },
  number: {
    minWidth: 22,
  },
  listText: {
    flex: 1,
  },
  spacer: {
    height: 4,
  },
});
