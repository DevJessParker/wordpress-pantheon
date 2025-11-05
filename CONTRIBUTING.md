# Contributing Guidelines

Thank you for considering contributing to this project! This document outlines our development workflow and best practices.

## 🤝 How to Contribute

### 1. Fork and Clone
```bash
# Fork the repository on GitHub, then:
git clone https://github.com/YOUR-USERNAME/wordpress-pantheon.git
cd wordpress-pantheon
```

### 2. Set Up Development Environment
```bash
# Follow the setup guide
make setup
make start
make pull
```

### 3. Create a Feature Branch
```bash
git checkout -b feature/your-feature-name
# or
git checkout -b fix/bug-description
```

### 4. Make Your Changes

Follow these guidelines:

#### Code Standards
- Follow [WordPress Coding Standards](https://developer.wordpress.org/coding-standards/wordpress-coding-standards/)
- Use meaningful variable and function names
- Comment complex logic
- Keep functions small and focused

#### Testing
```bash
# Run code quality checks
make phpcs

# Run security checks
make security

# Test locally
make test
```

#### Commit Messages
Use clear, descriptive commit messages:

**Good:**
```
Add database sync retry logic

- Added exponential backoff for failed syncs
- Improved error messages
- Added timeout configuration
```

**Bad:**
```
fixed stuff
```

**Format:**
```
<type>: <subject>

<body>

<footer>
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

### 5. Push and Create Pull Request
```bash
git push origin feature/your-feature-name
```

Then create a Pull Request on GitHub with:
- Clear title and description
- Reference any related issues (#123)
- Screenshots for UI changes
- Test results

## 🔍 Code Review Process

1. **Automated Checks**: CI/CD runs tests automatically
2. **Peer Review**: At least one approval required
3. **Testing**: Verify changes work on Dev environment
4. **Merge**: Squash and merge to main branch

## 📝 Development Workflow

### For Bug Fixes

1. Create issue describing the bug
2. Create branch: `fix/issue-123-description`
3. Write tests that fail (if applicable)
4. Fix the bug
5. Verify tests pass
6. Submit PR referencing the issue

### For New Features

1. Discuss feature in an issue first
2. Get approval before starting work
3. Create branch: `feature/feature-name`
4. Develop feature with tests
5. Update documentation
6. Submit PR with detailed description

### For Documentation

1. Create branch: `docs/what-you-are-documenting`
2. Make changes
3. Ensure all links work
4. Check formatting renders correctly
5. Submit PR

## 🧪 Testing Guidelines

### Before Submitting PR

- [ ] Code follows WordPress coding standards
- [ ] No PHP errors or warnings
- [ ] Tested on local environment
- [ ] Security check passes
- [ ] Documentation updated
- [ ] Commit messages are clear

### Testing Locally

```bash
# Start environment
make start

# Pull latest data
make pull

# Make your changes...

# Test your changes
make test

# Test specific functionality
lando wp --info
lando security-check

# Check logs
lando logs
```

## 🔒 Security

### Reporting Security Issues

**DO NOT** open public issues for security vulnerabilities.

Instead:
1. Email: security@yourcompany.com (update this)
2. Include detailed description
3. Include steps to reproduce
4. We'll respond within 48 hours

### Security Best Practices

- Never commit secrets or credentials
- Use environment variables for sensitive data
- Sanitize and validate all inputs
- Escape all outputs
- Use prepared statements for database queries
- Follow [OWASP guidelines](https://owasp.org/www-project-top-ten/)

## 📋 Pull Request Checklist

Before submitting your PR, ensure:

- [ ] Branch is up to date with main
- [ ] Tests pass locally
- [ ] Code follows style guidelines
- [ ] Documentation is updated
- [ ] Commit messages are clear
- [ ] PR description is detailed
- [ ] No merge conflicts
- [ ] Screenshots included (if UI changes)
- [ ] Tested on Dev environment

## 🎯 Coding Standards

### PHP

```php
// Good
function get_user_posts( $user_id ) {
    if ( ! is_numeric( $user_id ) ) {
        return array();
    }

    return get_posts( array(
        'author' => $user_id,
        'post_type' => 'post',
    ) );
}

// Bad
function getUserPosts($userId) {
    return get_posts(['author'=>$userId]);
}
```

### JavaScript

```javascript
// Good
const getUserData = async (userId) => {
    if (!userId) {
        return null;
    }

    try {
        const response = await fetch(`/api/users/${userId}`);
        return await response.json();
    } catch (error) {
        console.error('Error fetching user:', error);
        return null;
    }
};

// Bad
function getUserData(userId) {
    return fetch('/api/users/'+userId).then(r=>r.json());
}
```

### CSS

```css
/* Good */
.site-header {
    display: flex;
    align-items: center;
    padding: 1rem;
}

/* Bad */
.siteHeader{display:flex;align-items:center;padding:1rem}
```

## 🚀 Deployment Process

1. **Development**: Work on feature branch
2. **Testing**: PR triggers tests on Dev environment
3. **Review**: Code review by team
4. **Merge**: Merge to main branch
5. **Deploy**: Automatic deploy to Pantheon Dev
6. **QA**: Test on Dev environment
7. **Staging**: Deploy to Test (manual)
8. **Production**: Deploy to Live (manual)

## 📚 Resources

- [WordPress Developer Handbook](https://developer.wordpress.org/)
- [Pantheon Documentation](https://pantheon.io/docs)
- [Lando Documentation](https://docs.lando.dev/)
- [Git Best Practices](https://git-scm.com/book/en/v2)

## ❓ Questions?

- Open an issue for general questions
- Join our Slack channel (if available)
- Check existing documentation
- Review closed issues for similar questions

## 📄 License

By contributing, you agree that your contributions will be licensed under the same license as the project (MIT).

---

Thank you for contributing! 🎉
