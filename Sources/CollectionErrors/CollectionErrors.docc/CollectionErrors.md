# ``CollectionErrors``

The typed errors that the collections' `checked:` spellings, and their invariant-keeping
mutations, throw.

## Overview

Every module that throws one of these re-exports this module, so `import RangeTrees` alone brings
``IndexOutOfRange`` into scope, and the umbrella module sees one type however many collections
throw it.

## Topics

### Errors

- ``IndexOutOfRange``
- ``DuplicateKey``
- ``OverlappingKeys``
- ``EmptyRange``
- ``NotANumber``
