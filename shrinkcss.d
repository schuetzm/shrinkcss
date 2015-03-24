struct Lexem
{
    enum Type
    {
        Invalid,
        Comment,
        Whitespace,
        String,
        Url,
        Number,
        Word,
        Operator,
        Punctuation,
    }

    Type type;
    const(char)[] content;
}

struct ByLexem(T)
{
private:
    T input;

    T advance(size_t count)
    {
        assert(input.length >= count);
        T result = input[0 .. count];
        input = input[count .. $];
        return result;
    }

    T readComment()
    {
        assert(input.length > 1 && input[0] == '/' && input[1] == '*');
        size_t index = 2;   // skip "/*"
        while(index < input.length)
        {
            if(input[index] == '/' && input[index-1] == '*')
                break;
            index++;
        }
        if(index < input.length)
            index++;        // not at EOF yet
        return advance(index);
    }

    T readWhitespace()
    {
        size_t index = 0;
        loop: while(index < input.length)
        {
            switch(input[index])
            {
            case '\n':
            case '\r':
            case '\f':
            case '\t':
            case ' ':
                index++;
                break;
            default:
                break loop;
            }
        }
        return advance(index);
    }

    T readWord()
    {
        size_t index = 0;
        loop: while(index < input.length)
        {
            switch(input[index])
            {
            case '@':
            case '!':
            case '.':
            case '%':
            case '_':
            case '-':
            case '#':
            case '\\':
            case '[':
            case ']':
            case '=':
            case 'a': .. case 'z':
            case 'A': .. case 'Z':
            case '0': .. case '9':
            case '\240': .. case '\377':
                index++;
                break;
            default:
                break loop;
            }
        }
        return advance(index);
    }

    size_t find(size_t index, char what)
    {
        char prev;
        while(index < input.length)
        {
            if(input[index] == what && prev != '\\')
                break;
            prev = input[index];
            index++;
        }
        if(index < input.length)
            index++;    // not at EOF
        return index;
    }

    T readUrl(T saved)
    {
        input = saved;
        assert(input.length >= 4 && input[0 .. 4] == "url(");
        size_t index = 4;   // skip "url("
        if(input.length > 4 && (input[4] == '\'' || input[4] == '"'))
            index = find(index, input[4]);
        index = find(index, ')');
        return advance(index);
    }

    void lex()
    {
        if(input.length == 0) with(Lexem.Type)
        {
            this.front = Lexem(Invalid);
            return;
        }

        switch(input[0]) with(Lexem.Type)
        {
        case '\n':
        case '\r':
        case '\f':
        case '\t':
        case ' ':
            this.front = Lexem(Whitespace, readWhitespace);
            break;

        case ',':
        case ';':
        case ':':
        case '(':
        case ')':
        case '{':
        case '}':
        case '>':
        case '+':
            this.front = Lexem(Punctuation, advance(1));
            break;

        case '\'':
        case '"':
            size_t index = find(1, input[0]);
            this.front = Lexem(String, advance(index));
            break;

        case '/':
            if(input.length > 1 && input[1] == '*')
            {
                this.front = Lexem(Comment, readComment);
            }
            else
            {
                this.front = Lexem(Punctuation, advance(1));
            }
            break;

        case '*':
            this.front = Lexem(Operator, advance(1));
            break;

        case '@':
        case '!':
        case '.':
        case '%':
        case '_':
        case '-':
        case '#':
        case '\\':
        case '[':
        case ']':
        case '=':
        case 'a': .. case 'z':
        case 'A': .. case 'Z':
        case '0': .. case '9':
        case '\240': .. case '\377':
            T saved = input;
            T word = readWord;
            if(word == "url" && input.length > 0 && input[0] == '(')
                this.front = Lexem(Url, readUrl(saved));
            else
                this.front = Lexem(Word, word);
            break;

        default:
            import std.exception : enforce;
            import std.format : format;
            enforce(false, format("unhandled ['%c' %d]", input[0], input[0]));
        }
    }

public:
    Lexem front;

    this(T input)
    {
        this.input = input;
        lex();
    }

    @property empty() const
    {
        return front.type == Lexem.Type.Invalid;
    }

    void popFront()
    {
        assert(!empty);
        lex();
    }
}

auto byLexem(T)(T input)
{
    return ByLexem!T(input);
}

void main()
{
    import std.stdio;
    import std.array : array, join;
    import std.algorithm : map;
    import std.range : chain;

    const(char)[] input = stdin.byLine(KeepTerminator.yes).map!dup.array.join;
    auto lexems = input.byLexem;

    Lexem current, prev;
    bool semicolon;
    foreach(next; lexems.chain([Lexem()]))
    {
        switch(current.type) with(Lexem.Type)
        {
        case Comment:
        case Whitespace:
            if(next.type != Whitespace &&
               next.type != Comment &&
               next.type != Punctuation &&
               prev.type != Punctuation)
            write(" ");
            break;

        case Invalid:
            break;

        case Punctuation:
            if(current.content == ";")
            {
                semicolon = true;
                break;
            }
            goto default;

        default:
            if(semicolon)
            {
                semicolon = false;
                if(!(current.type == Punctuation && current.content == "}"))
                    write(";");
            }
            write(current.content);
        }
        prev = current;
        current = next;
    }
}
