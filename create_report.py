import logging
import os
import re
from datetime import datetime, timezone, timedelta
from typing import Callable

from github import Github, Auth, UnknownObjectException
from github.Commit import Commit
from github.PullRequest import PullRequest
from pylatex import Document, Section, Package, NoEscape, escape_latex, Subsection, LongTable, Tabular, Command


SQUASH_MERGE_DATE = datetime(2025, 11, 12, tzinfo=timezone(timedelta(hours=1)))
GITHUB_REPO = 'scriptor1000/homeworks'

MAIN_COMMITS_HEADLINE = 'Commit History of Main'
PULL_REQUESTS_HEADLINE = 'Commit History of Pull Requests'

PULL_REQUEST_SECTION: Callable[[PullRequest], str] = lambda pr: f'PR #{pr.number}: {pr.title}'

NAME_ALIAS = {
    'max': 'Max',
    'scriptor': 'Max',
    'soroush': 'Soroush',
    '12sor21': 'Soroush'
}

MANUAL_PR_NUMBERS = {}

logger = logging.getLogger(__name__)
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')


def underline(text) -> Command:
    return Command('underline', text)


def texttt(text) -> Command:
    return Command('texttt', text)


def hyperlink(url, text) -> Command:
    return Command('href', [url, underline(text)])


def author(commit: Commit | PullRequest):
    if isinstance(commit, PullRequest):
        user = commit.user
    else:
        user = commit.commit.author
    if n := user.name:
        name = n.strip()
    else:
        name = user.login.strip()
    return NAME_ALIAS.get(name.lower(), name)


def date(commit: Commit):
    return commit.commit.author.date


def summary(commit: Commit):
    return commit.commit.message.splitlines()[0]


class HistoryAnalyzer:
    def __init__(self):
        auth = None
        if token := os.getenv('GITHUB_TOKEN'):
            auth = Auth.Token(token)
        self.g = Github(auth=auth)
        self.origin_repo = self.g.get_repo(GITHUB_REPO)

        self.pull_requests: list[PullRequest] = []

    def _add_commit_to_table(self, table: LongTable, commit: Commit, pr_number: int | None = None):
        if commit.sha == 'c9f6eedeaed033611a0473788eff135e894c8128':
            commit_summary = 'Initial commit'
        else:
            commit_summary = (self._check_for_issue(summary(commit)) if pr_number is not None
                              else self._check_for_pr(summary(commit)))
        path = '/commit/'
        if pr_number is not None:
            path = f'/pull/{pr_number}/commits/'

        table.add_row([
            hyperlink(f'https://github.com/{GITHUB_REPO}{path}{commit.sha}',
                      texttt(commit.sha[:7])),
            author(commit),
            f'{date(commit):%d.%m.%Y}',
            commit_summary
        ])

    def _check_for_issue(self, commit_summary) -> str:
        match = re.search(r'#\d+', commit_summary)

        if not match:
            return commit_summary

        issue_number = match.group(0)[1:]  # Remove the '#' character
        try:
            issue = self.origin_repo.get_issue(int(issue_number))

            before = escape_latex(commit_summary[:match.start()])
            after = escape_latex(self._check_for_issue(commit_summary[match.end():]))
            link = hyperlink(f'https://github.com/{GITHUB_REPO}/issues/{issue_number}', f'#{issue_number}')
            ref = Command('footnote', issue.title)
            return NoEscape(f'{before}{link.dumps()}{ref.dumps()}{after}')
        except UnknownObjectException:
            return commit_summary

    def add_pull_requests(self, doc: Document):
        subsections = []
        for pr in self.pull_requests:
            logger.info(f'Adding pull request {pr.number}...')
            subsection = Subsection(PULL_REQUEST_SECTION(pr), label=f'pr:{pr.number}')

            table = Tabular(r'l l')
            table.add_row([f'Autor:', author(pr)])
            table.add_row([f'Erstellt am: ', f'{pr.created_at:%d.%m.%Y}'])
            subsection.append(table)

            table = LongTable(r'l l l p{12cm}')
            for c in pr.get_commits():
                self._add_commit_to_table(table, c, pr_number=pr.number)
            subsection.append(table)

            subsections.append(subsection)

        with doc.create(Section(PULL_REQUESTS_HEADLINE)):
            for subsection in subsections:
                doc.append(subsection)

    def _check_for_pr(self, commit_summary) -> str:
        match = re.search(r'#\d+', commit_summary)

        if not match:
            pr_number = MANUAL_PR_NUMBERS.get(commit_summary, None)
        else:
            pr_number = match.group(0)[1:]  # Remove the '#' character

        if not pr_number:
            logger.warning(f'No issue found in the commit "{commit_summary}" - please check manually.')
            return commit_summary
        try:
            pr = self.origin_repo.get_pull(int(pr_number))
        except UnknownObjectException:
            return commit_summary
        self.pull_requests.append(pr)

        before = escape_latex(commit_summary[:match.start()])
        after = escape_latex(commit_summary[match.end():])
        link = hyperlink(f'https://github.com/{GITHUB_REPO}/pull/{pr_number}', f'#{pr_number}')
        ref = Command('footnote', NoEscape(f'siehe Sektion {Command('ref', 'pr:' + pr_number).dumps()} '
                                           f'für mehr Informationen über den PR {escape_latex(pr.title)}'))
        return NoEscape(f'{before}{link.dumps()}{ref.dumps()}{after}')

    def _add_past_squash_merge_history(self, table: LongTable):
        if GITHUB_REPO != 'scriptor1000/homeworks':
            return
        logger.info('Adding past squash merge to document...')
        commits = self.origin_repo.get_commits(
            until=SQUASH_MERGE_DATE,
            sha='main'
        )
        for c in commits:
            s = summary(c)
            is_merge_commit = len(c.parents) > 1
            is_squash_merge = len(c.parents) <= 1 and re.search(r'#\d+', s)
            is_initial_commit = c.sha == 'c9f6eedeaed033611a0473788eff135e894c8128'
            exclude_merge = c.sha == '183674be8dfc78f59c6facf12861e89f19c918b0'
            exclude_fix = 'fix' in summary(c).lower()

            if is_merge_commit and not exclude_merge or is_squash_merge and not exclude_fix or is_initial_commit:
                self._add_commit_to_table(table, c)

    def add_main_history(self, doc: Document):
        logger.info('Adding main commit history to document...')
        commits = self.origin_repo.get_commits(
            since=SQUASH_MERGE_DATE,
            sha='main'
        )
        table = LongTable(r'l l l p{12cm}')
        for c in commits:
            self._add_commit_to_table(table, c)

        self._add_past_squash_merge_history(table)
        with doc.create(Section(MAIN_COMMITS_HEADLINE)):
            doc.append(table)


def add_explanation(doc: Document):
    with doc.create(Section('Erklärung dieses Berichtshefts')):
        doc.append(
            'Wir haben bei der Entwicklung das Versionierungssystem Git zusammen mit GitHub verwendet. '
            'Dabei wird jede Änderung im Code als sogenannter Commit gespeichert. '
            'Durch sogenannte Abzweigungen (Branches) ist es möglich, an mehreren Funktionen gleichzeitig '
            'zu arbeiten, ohne sich dabei in die Quere zu kommen. '
            'Um eine Abzweigung zurück in den Hauptzweig (bei uns „main“) zu führen, wird ein sogenannter '
            'Pull Request (kurz PR) erstellt. '
            'Nach gegenseitiger Überprüfung und Bestätigung der Änderungen werden diese im Rahmen eines '
            'Pull Requests in den Hauptzweig übernommen; dieser Vorgang wird „mergen“ genannt.'
            'Dabei wird wiederum ein eigener Commit auf dem Hauptzweig erstellt.'
        )
        doc.append('\n\n')
        doc.append(
            'Im Folgenden stehen in Tabellen sämtliche Commits. '
            'Zuerst werden alle Commits auf dem Hauptzweig dargestellt; '
            'sie sind über Fußnoten mit den dazugehörigen Pull Requests verknüpft. '
            'Anschließend finden Sie eine Auflistung aller Pull Requests mit ihren jeweiligen Commits.'
        )
        doc.append('\n\n')
        doc.append('Ein Commit wird in den Tabellen wie folgt dargestellt:')
        table = LongTable(r'l l l p{12cm}')
        table.add_row(['Commit-Hash', 'Autor', 'Datum', 'Zusammenfassung'])
        doc.append(table)
        doc.append(Command(
            'noindent',
            'Der Commit-Hash ist eine eindeutige Kennung des Commits. '
            'Zudem verlinkt der Hash hier auf den entsprechenden Commit auf GitHub; '
            'dort können Sie jede Änderung im Detail nachvollziehen.'
        ))

if __name__ == '__main__':
    analyzer = HistoryAnalyzer()

    geometry_options = {'margin':'1.5cm'}
    doc = Document('article', geometry_options=geometry_options)
    doc.packages.append(Package('hyperref', options='colorlinks=true, urlcolor=blue, linkcolor=blue'))

    add_explanation(doc)
    analyzer.add_main_history(doc)
    analyzer.add_pull_requests(doc)

    logger.info('Generating .TEX...')

    with open("report.tex", "w", encoding="utf-8") as f:
        doc.dump(f)
