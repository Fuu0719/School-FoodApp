param(
  [int]$PageSize = 300
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

function Read-DotEnv([string]$Path) {
  $values = @{}
  if (-not (Test-Path -LiteralPath $Path)) { return $values }
  foreach ($line in Get-Content -LiteralPath $Path -Encoding UTF8) {
    if ($line -match '^\s*#' -or $line -notmatch '=') { continue }
    $parts = $line.Split('=', 2)
    $values[$parts[0].Trim()] = $parts[1].Trim().Trim('"').Trim("'")
  }
  return $values
}

$backendDir = Split-Path -Parent $PSScriptRoot
$config = Read-DotEnv (Join-Path $backendDir '.env')
$hostName = if ($config['DB_HOST']) { $config['DB_HOST'] } else { '127.0.0.1' }
$port = if ($config['DB_PORT']) { $config['DB_PORT'] } else { '3307' }
$user = if ($config['DB_USER']) { $config['DB_USER'] } else { 'food_app' }
$database = if ($config['DB_NAME']) { $config['DB_NAME'] } else { 'shan_jie_ren_yi' }
$password = $config['DB_PASSWORD']
if (-not $password) {
  [System.Windows.Forms.MessageBox]::Show('DB_PASSWORD is missing from backend\.env.', 'Database Viewer') | Out-Null
  exit 1
}

$mysqlCandidates = @(
  (Get-Command mysql.exe -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -First 1),
  'C:\Program Files\MySQL\MySQL Server 26.7\bin\mysql.exe',
  'C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe'
) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }
if (-not $mysqlCandidates) {
  [System.Windows.Forms.MessageBox]::Show('mysql.exe was not found.', 'Database Viewer') | Out-Null
  exit 1
}
$mysql = $mysqlCandidates[0]

function Invoke-Database([string]$Sql, [switch]$NoHeaders) {
  $previousPassword = $env:MYSQL_PWD
  try {
    $env:MYSQL_PWD = $password
    $arguments = @(
      '--host', $hostName,
      '--port', $port,
      '--user', $user,
      '--database', $database,
      '--default-character-set=utf8mb4',
      '--batch',
      '--raw'
    )
    if ($NoHeaders) { $arguments += '--skip-column-names' }
    $arguments += @('--execute', $Sql)
    $result = @(& $mysql @arguments 2>&1)
    if ($LASTEXITCODE -ne 0) { throw ($result -join [Environment]::NewLine) }
    return $result
  } finally {
    $env:MYSQL_PWD = $previousPassword
  }
}

function Escape-Like([string]$Value) {
  return $Value.Replace('\', '\\').Replace("'", "''").Replace('%', '\%').Replace('_', '\_')
}

$form = New-Object System.Windows.Forms.Form
$form.Text = 'MealMind - Read-only Database Viewer'
$form.StartPosition = 'CenterScreen'
$form.WindowState = 'Maximized'
$form.MinimumSize = New-Object System.Drawing.Size(980, 620)
$form.Font = New-Object System.Drawing.Font('Microsoft JhengHei UI', 10)

$toolbar = New-Object System.Windows.Forms.FlowLayoutPanel
$toolbar.Dock = 'Top'
$toolbar.Height = 54
$toolbar.Padding = New-Object System.Windows.Forms.Padding(10, 10, 10, 6)
$toolbar.WrapContents = $false

$tableLabel = New-Object System.Windows.Forms.Label
$tableLabel.Text = 'Table'
$tableLabel.AutoSize = $true
$tableLabel.Margin = New-Object System.Windows.Forms.Padding(0, 7, 6, 0)

$tableSelect = New-Object System.Windows.Forms.ComboBox
$tableSelect.DropDownStyle = 'DropDownList'
$tableSelect.Width = 250

$searchBox = New-Object System.Windows.Forms.TextBox
$searchBox.Width = 260
$searchBox.Margin = New-Object System.Windows.Forms.Padding(18, 2, 4, 0)

$searchButton = New-Object System.Windows.Forms.Button
$searchButton.Text = 'Search'
$searchButton.AutoSize = $true

$clearButton = New-Object System.Windows.Forms.Button
$clearButton.Text = 'Clear'
$clearButton.AutoSize = $true

$refreshButton = New-Object System.Windows.Forms.Button
$refreshButton.Text = 'Refresh'
$refreshButton.AutoSize = $true
$refreshButton.Margin = New-Object System.Windows.Forms.Padding(18, 2, 4, 0)

$previousButton = New-Object System.Windows.Forms.Button
$previousButton.Text = 'Previous'
$previousButton.AutoSize = $true
$previousButton.Margin = New-Object System.Windows.Forms.Padding(18, 2, 4, 0)

$nextButton = New-Object System.Windows.Forms.Button
$nextButton.Text = 'Next'
$nextButton.AutoSize = $true

$pageLabel = New-Object System.Windows.Forms.Label
$pageLabel.AutoSize = $true
$pageLabel.Margin = New-Object System.Windows.Forms.Padding(10, 7, 0, 0)

$toolbar.Controls.AddRange(@(
  $tableLabel, $tableSelect, $searchBox, $searchButton, $clearButton,
  $refreshButton, $previousButton, $nextButton, $pageLabel
))

$grid = New-Object System.Windows.Forms.DataGridView
$grid.Dock = 'Fill'
$grid.ReadOnly = $true
$grid.AllowUserToAddRows = $false
$grid.AllowUserToDeleteRows = $false
$grid.AllowUserToOrderColumns = $true
$grid.AutoSizeColumnsMode = 'DisplayedCells'
$grid.SelectionMode = 'FullRowSelect'
$grid.MultiSelect = $false
$grid.BackgroundColor = [System.Drawing.Color]::White
$grid.RowHeadersVisible = $false
$grid.ClipboardCopyMode = 'EnableAlwaysIncludeHeaderText'

$status = New-Object System.Windows.Forms.StatusStrip
$statusLabel = New-Object System.Windows.Forms.ToolStripStatusLabel
$statusLabel.Spring = $true
$statusLabel.TextAlign = 'MiddleLeft'
$status.Items.Add($statusLabel) | Out-Null

$form.Controls.Add($grid)
$form.Controls.Add($toolbar)
$form.Controls.Add($status)

$script:page = 0
$script:columns = @()

function Load-Table {
  try {
    $table = [string]$tableSelect.SelectedItem
    if ($table -notmatch '^[A-Za-z0-9_]+$') { return }
    $script:columns = @(Invoke-Database "SHOW COLUMNS FROM ``$table``;" | ConvertFrom-Csv -Delimiter "`t" | ForEach-Object Field)
    $conditions = ''
    $keyword = $searchBox.Text.Trim()
    if ($keyword) {
      $escaped = Escape-Like $keyword
      $parts = $script:columns | ForEach-Object { "CAST(``$_`` AS CHAR) LIKE '%$escaped%' ESCAPE '\\'" }
      $conditions = ' WHERE ' + ($parts -join ' OR ')
    }
    $offset = $script:page * $PageSize
    $count = [int](Invoke-Database "SELECT COUNT(*) FROM ``$table``$conditions;" -NoHeaders | Select-Object -First 1)
    $rows = @(Invoke-Database "SELECT * FROM ``$table``$conditions LIMIT $PageSize OFFSET $offset;")
    if ($rows.Count -gt 1) {
      $grid.DataSource = @($rows | ConvertFrom-Csv -Delimiter "`t")
    } else {
      $empty = New-Object System.Data.DataTable
      foreach ($column in $script:columns) { [void]$empty.Columns.Add($column) }
      $grid.DataSource = $empty
    }
    $pages = [Math]::Max(1, [Math]::Ceiling($count / $PageSize))
    $pageLabel.Text = "Page $($script:page + 1) / $pages"
    $previousButton.Enabled = $script:page -gt 0
    $nextButton.Enabled = ($offset + $PageSize) -lt $count
    $statusLabel.Text = "$database.$table - $count rows - read only"
  } catch {
    [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Read failed') | Out-Null
  }
}

$tableSelect.add_SelectedIndexChanged({ $script:page = 0; $searchBox.Clear(); Load-Table })
$searchButton.add_Click({ $script:page = 0; Load-Table })
$searchBox.add_KeyDown({ if ($_.KeyCode -eq 'Enter') { $script:page = 0; Load-Table; $_.SuppressKeyPress = $true } })
$clearButton.add_Click({ $searchBox.Clear(); $script:page = 0; Load-Table })
$refreshButton.add_Click({ Load-Table })
$previousButton.add_Click({ if ($script:page -gt 0) { $script:page--; Load-Table } })
$nextButton.add_Click({ $script:page++; Load-Table })

try {
  $tables = @(Invoke-Database 'SHOW TABLES;' -NoHeaders | Where-Object { $_ -match '^[A-Za-z0-9_]+$' })
  [void]$tableSelect.Items.AddRange([object[]]$tables)
  if ($tables.Count -gt 0) { $tableSelect.SelectedIndex = 0 }
} catch {
  [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Connection failed') | Out-Null
  exit 1
}

[void]$form.ShowDialog()
