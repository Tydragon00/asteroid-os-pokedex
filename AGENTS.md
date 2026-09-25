# Agent instructions

## Always work on a feature branch

Never commit directly to `main`. Before touching any file, create a
dedicated branch for the change and keep the work there:

```sh
git checkout -b fix/short-description main
```

Pick a descriptive prefix (`fix/`, `feature/`, `docs/`, ...). Do not mix
unrelated changes into an existing branch; create a new one instead.
