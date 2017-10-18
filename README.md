# Elm Docs Generator

> A markdown documentation generator for Elm.


## Install

```
grove install panosoft/elm-docs
```

_Note: [Grove](https://github.com/panosoft/elm-grove) is an advanced package manager for Elm and can be found [here](https://github.com/panosoft/elm-grove)._


## Usage

Document your code using the [Elm language documentation format](http://package.elm-lang.org/help/documentation-format) and this library will render that documentation as Markdown.


## Example

### Simple Example
To see how this works, just look at this repository. [Generator.elm](src/Docs/Generator.elm) has a module with one `@docs` element. Calling the `Docs.Generator.generate` function produces [Docs.Generator.md](elm-docs/Docs.Generator.md).

### Advanced Example
For a more advanced example, take a look at the repository [panosoft/elm-utils](https://github.com/panosoft/elm-utils). The most advanced example is in [Utils.Ops.elm](https://github.com/panosoft/elm-utils/blob/master/src/Utils/Ops.elm) where the markdown has been categorized:

```elm
{-| Utility operators.

  - [Boolean](#boolean)
  - [List](#list)
  - [Maybe](#maybe)
  - [Result](#result)


# Boolean

@docs (?), (?!)


# List

@docs (!!)


# Maybe

@docs (?=), (?!=), (|?>), (|?->), (|?!->), (|?-->), (|?!-->), (|?--->), (|?!--->), (|?**>), (|?!**>), (|?***>), (|?!***>), (|?****>), (|?!****>)


# Result

@docs (|??>), (??=), (|??->), (|??-->), (|??**>), (|??***>), (|??****>)

-}

```

You can see what this produces at [Utils.Ops.md](https://github.com/panosoft/elm-utils/blob/master/elm-docs/Utils.Ops.md).


### Table of Contents

The documentation has been broken up into categories. A table of contents has been created to allow the user to jump to the appropriate section:

```markdown
- [Boolean](#boolean)
- [List](#list)
- [Maybe](#maybe)
- [Result](#result)
```

Each `@docs` section will get the documentation for the functions in its list. The function documentation will be made up from the comments of those functions which is also in markdown.

Unlike the manual Table of Contents above, each `@docs` section will automatically be preceded with a Table of Contents for the functions in that `@docs` statement.


## Elm Format issues

If you're used to using the back-ticks to begin a block of code in markdown, e.g.:

    ```elm
		-- Some Elm code here
    ```

`elm-format` will rewrite your comments to use 4 spaces.

But it will only do this for elm code blocks. This is not a problem since this library will change any code preceded with 4 spaces to an Elm block so that docs will have syntax coloring.

If, for some reason, you'd like to embed code from a different language, e.g. Javascript, then you MUST use back-ticks.

## Api

- [Generator](elm-docs/Docs.Generator.md)
