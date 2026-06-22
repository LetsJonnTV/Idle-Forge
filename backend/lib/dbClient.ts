import { Pool } from 'pg';

type Primitive = string | number | boolean | null;

interface DbError {
  code?: string;
  message: string;
  details?: string;
}

interface DbResult<T = any> {
  data: T | null;
  error: DbError | null;
}

interface UpsertOptions {
  onConflict?: string;
}

interface OrderBy {
  column: string;
  ascending: boolean;
}

interface SelectColumn {
  type: 'column';
  name: string;
}

interface SelectRelation {
  type: 'relation';
  alias: string;
  fkColumn: string;
  nestedColumns: string[];
}

type ParsedSelect = SelectColumn | SelectRelation;

const DATABASE_URL = process.env.DATABASE_URL;

if (!DATABASE_URL) {
  console.warn('DATABASE_URL is not configured. API calls that require Postgres will fail.');
}

const pool = new Pool({
  connectionString: DATABASE_URL,
  max: 20,
  idleTimeoutMillis: 30_000,
  connectionTimeoutMillis: 10_000,
});

const PLAYER_FK_COLUMNS = new Set([
  'challenger_id',
  'defender_id',
  'winner_id',
  'requester_id',
  'addressee_id',
  'player_id',
  'inviter_id',
  'leader_id',
  'host_id',
  'guest_id',
]);

function toDbError(error: unknown): DbError {
  if (!error || typeof error !== 'object') {
    return { message: 'Unknown database error' };
  }

  const err = error as { code?: string; message?: string; detail?: string };
  return {
    code: err.code,
    message: err.message ?? 'Database error',
    details: err.detail,
  };
}

function splitTopLevel(input: string): string[] {
  const parts: string[] = [];
  let depth = 0;
  let start = 0;

  for (let i = 0; i < input.length; i += 1) {
    const char = input[i];
    if (char === '(') depth += 1;
    if (char === ')') depth = Math.max(0, depth - 1);
    if (char === ',' && depth === 0) {
      const token = input.slice(start, i).trim();
      if (token) parts.push(token);
      start = i + 1;
    }
  }

  const tail = input.slice(start).trim();
  if (tail) parts.push(tail);
  return parts;
}

function parseSelectColumns(selectClause: string): ParsedSelect[] {
  if (!selectClause || selectClause.trim() === '*' || selectClause.trim() === '') {
    return [{ type: 'column', name: '*' }];
  }

  const cleaned = selectClause.replace(/\s+/g, ' ').trim();
  const tokens = splitTopLevel(cleaned);

  return tokens.map((token) => {
    const relationMatch = token.match(/^([a-zA-Z_][\w]*):([a-zA-Z_][\w]*)\((.+)\)$/);
    if (!relationMatch) {
      return { type: 'column', name: token } as SelectColumn;
    }

    const [, alias, fkColumn, nested] = relationMatch;
    return {
      type: 'relation',
      alias,
      fkColumn,
      nestedColumns: splitTopLevel(nested).map((c) => c.trim()).filter(Boolean),
    } as SelectRelation;
  });
}

function resolveRelationTable(baseTable: string, fkColumn: string): string | null {
  if (PLAYER_FK_COLUMNS.has(fkColumn)) {
    return 'players';
  }
  if (baseTable === 'clan_invites' && fkColumn === 'clan_id') {
    return 'clans';
  }
  return null;
}

function buildConditionFromExpression(expression: string, values: Primitive[]): string {
  const match = expression.match(/^([a-zA-Z_][\w]*)\.([a-z]+)\.(.+)$/);
  if (!match) {
    throw new Error(`Unsupported condition expression: ${expression}`);
  }

  const [, column, operator, value] = match;
  switch (operator) {
    case 'eq': {
      values.push(value);
      return `"${column}" = $${values.length}`;
    }
    case 'neq': {
      values.push(value);
      return `"${column}" <> $${values.length}`;
    }
    default:
      throw new Error(`Unsupported operator in expression: ${operator}`);
  }
}

class QueryBuilder<T = any>
  implements PromiseLike<DbResult<T>>
{
  private readonly table: string;
  private mode: 'select' | 'insert' | 'update' | 'delete' | 'upsert' = 'select';
  private selectClause = '*';
  private selectParsed: ParsedSelect[] = [{ type: 'column', name: '*' }];
  private updatePayload: Record<string, unknown> | null = null;
  private insertPayload: Record<string, unknown>[] = [];
  private upsertPayload: Record<string, unknown>[] = [];
  private upsertOptions: UpsertOptions = {};
  private filters: string[] = [];
  private values: Primitive[] = [];
  private orderBys: OrderBy[] = [];
  private limitCount: number | null = null;
  private expectSingle = false;
  private expectMaybeSingle = false;
  private returnRows = false;

  constructor(table: string) {
    this.table = table;
  }

  select(columns = '*'): QueryBuilder<T> {
    this.selectClause = columns;
    this.selectParsed = parseSelectColumns(columns);
    this.returnRows = true;
    return this;
  }

  insert(payload: Record<string, unknown> | Record<string, unknown>[]): QueryBuilder<T> {
    this.mode = 'insert';
    this.insertPayload = Array.isArray(payload) ? payload : [payload];
    return this;
  }

  update(payload: Record<string, unknown>): QueryBuilder<T> {
    this.mode = 'update';
    this.updatePayload = payload;
    return this;
  }

  delete(): QueryBuilder<T> {
    this.mode = 'delete';
    return this;
  }

  upsert(payload: Record<string, unknown> | Record<string, unknown>[], options?: UpsertOptions): QueryBuilder<T> {
    this.mode = 'upsert';
    this.upsertPayload = Array.isArray(payload) ? payload : [payload];
    this.upsertOptions = options ?? {};
    return this;
  }

  eq(column: string, value: Primitive): QueryBuilder<T> {
    this.values.push(value);
    this.filters.push(`"${column}" = $${this.values.length}`);
    return this;
  }

  neq(column: string, value: Primitive): QueryBuilder<T> {
    this.values.push(value);
    this.filters.push(`"${column}" <> $${this.values.length}`);
    return this;
  }

  gte(column: string, value: Primitive): QueryBuilder<T> {
    this.values.push(value);
    this.filters.push(`"${column}" >= $${this.values.length}`);
    return this;
  }

  ilike(column: string, value: string): QueryBuilder<T> {
    this.values.push(value);
    this.filters.push(`"${column}" ILIKE $${this.values.length}`);
    return this;
  }

  is(column: string, value: Primitive): QueryBuilder<T> {
    if (value === null) {
      this.filters.push(`"${column}" IS NULL`);
      return this;
    }
    this.values.push(value);
    this.filters.push(`"${column}" IS NOT DISTINCT FROM $${this.values.length}`);
    return this;
  }

  in(column: string, values: Primitive[]): QueryBuilder<T> {
    if (values.length === 0) {
      this.filters.push('1=0');
      return this;
    }
    const placeholders = values.map((value) => {
      this.values.push(value);
      return `$${this.values.length}`;
    });
    this.filters.push(`"${column}" IN (${placeholders.join(', ')})`);
    return this;
  }

  or(expression: string): QueryBuilder<T> {
    const groups = splitTopLevel(expression);
    const groupSql = groups
      .map((group) => {
        const andMatch = group.match(/^and\((.+)\)$/);
        if (andMatch) {
          const andConditions = splitTopLevel(andMatch[1]).map((part) =>
            buildConditionFromExpression(part, this.values),
          );
          return `(${andConditions.join(' AND ')})`;
        }
        return `(${buildConditionFromExpression(group, this.values)})`;
      })
      .join(' OR ');

    this.filters.push(`(${groupSql})`);
    return this;
  }

  order(column: string, options?: { ascending?: boolean }): QueryBuilder<T> {
    this.orderBys.push({ column, ascending: options?.ascending !== false });
    return this;
  }

  limit(count: number): QueryBuilder<T> {
    this.limitCount = count;
    return this;
  }

  single(): QueryBuilder<T> {
    this.expectSingle = true;
    return this;
  }

  maybeSingle(): QueryBuilder<T> {
    this.expectMaybeSingle = true;
    return this;
  }

  private buildSelectSql(): string {
    const relationParts = this.selectParsed.filter((part): part is SelectRelation => part.type === 'relation');
    const columnParts = this.selectParsed.filter((part): part is SelectColumn => part.type === 'column');

    const selectFragments: string[] = [];
    const joinFragments: string[] = [];

    if (columnParts.some((part) => part.name === '*')) {
      selectFragments.push('base.*');
    } else {
      for (const part of columnParts) {
        selectFragments.push(`base."${part.name}"`);
      }
    }

    for (const relation of relationParts) {
      const relatedTable = resolveRelationTable(this.table, relation.fkColumn);
      if (!relatedTable) {
        throw new Error(`Unsupported relation mapping for ${this.table}.${relation.fkColumn}`);
      }

      const relAlias = `rel_${relation.alias}`;
      joinFragments.push(
        `LEFT JOIN "${relatedTable}" ${relAlias} ON base."${relation.fkColumn}" = ${relAlias}."id"`,
      );

      const objectParts = relation.nestedColumns
        .map((column) => `'${column}', ${relAlias}."${column}"`)
        .join(', ');
      selectFragments.push(`json_build_object(${objectParts}) AS "${relation.alias}"`);
    }

    let sql = `SELECT ${selectFragments.join(', ')} FROM "${this.table}" base`;
    if (joinFragments.length > 0) {
      sql += ` ${joinFragments.join(' ')}`;
    }

    if (this.filters.length > 0) {
      sql += ` WHERE ${this.filters.join(' AND ')}`;
    }

    if (this.orderBys.length > 0) {
      const orderSql = this.orderBys
        .map((order) => `base."${order.column}" ${order.ascending ? 'ASC' : 'DESC'}`)
        .join(', ');
      sql += ` ORDER BY ${orderSql}`;
    }

    if (this.limitCount !== null) {
      sql += ` LIMIT ${this.limitCount}`;
    }

    return sql;
  }

  private buildInsertLikeSql(payload: Record<string, unknown>[], mode: 'insert' | 'upsert'): string {
    if (payload.length === 0) {
      throw new Error(`${mode} payload cannot be empty`);
    }

    const columns = Object.keys(payload[0]);
    if (columns.length === 0) {
      throw new Error(`${mode} payload cannot be empty`);
    }

    const rowPlaceholders: string[] = [];
    for (const row of payload) {
      const placeholders: string[] = [];
      for (const column of columns) {
        this.values.push((row[column] as Primitive | undefined) ?? null);
        placeholders.push(`$${this.values.length}`);
      }
      rowPlaceholders.push(`(${placeholders.join(', ')})`);
    }

    let sql = `INSERT INTO "${this.table}" (${columns.map((column) => `"${column}"`).join(', ')}) VALUES ${rowPlaceholders.join(', ')}`;

    if (mode === 'upsert') {
      const conflictColumns = (this.upsertOptions.onConflict ?? '')
        .split(',')
        .map((value) => value.trim())
        .filter(Boolean);

      if (conflictColumns.length === 0) {
        throw new Error('upsert requires onConflict columns');
      }

      const updateColumns = columns.filter((column) => !conflictColumns.includes(column));

      if (updateColumns.length === 0) {
        sql += ` ON CONFLICT (${conflictColumns.map((column) => `"${column}"`).join(', ')}) DO NOTHING`;
      } else {
        sql += ` ON CONFLICT (${conflictColumns.map((column) => `"${column}"`).join(', ')}) DO UPDATE SET ${updateColumns
          .map((column) => `"${column}" = EXCLUDED."${column}"`)
          .join(', ')}`;
      }
    }

    if (this.returnRows) {
      sql += ` RETURNING ${this.selectClause === '*' ? '*' : this.selectClause}`;
    }

    return sql;
  }

  private buildUpdateSql(): string {
    if (!this.updatePayload || Object.keys(this.updatePayload).length === 0) {
      throw new Error('update payload cannot be empty');
    }

    const assignments = Object.entries(this.updatePayload).map(([column, value]) => {
      this.values.push((value as Primitive | undefined) ?? null);
      return `"${column}" = $${this.values.length}`;
    });

    let sql = `UPDATE "${this.table}" SET ${assignments.join(', ')}`;
    if (this.filters.length > 0) {
      sql += ` WHERE ${this.filters.join(' AND ')}`;
    }
    if (this.returnRows) {
      sql += ` RETURNING ${this.selectClause === '*' ? '*' : this.selectClause}`;
    }
    return sql;
  }

  private buildDeleteSql(): string {
    let sql = `DELETE FROM "${this.table}"`;
    if (this.filters.length > 0) {
      sql += ` WHERE ${this.filters.join(' AND ')}`;
    }
    if (this.returnRows) {
      sql += ` RETURNING ${this.selectClause === '*' ? '*' : this.selectClause}`;
    }
    return sql;
  }

  private async execute(): Promise<DbResult<T>> {
    let sql: string;
    switch (this.mode) {
      case 'select':
        sql = this.buildSelectSql();
        break;
      case 'insert':
        sql = this.buildInsertLikeSql(this.insertPayload, 'insert');
        break;
      case 'upsert':
        sql = this.buildInsertLikeSql(this.upsertPayload, 'upsert');
        break;
      case 'update':
        sql = this.buildUpdateSql();
        break;
      case 'delete':
        sql = this.buildDeleteSql();
        break;
      default:
        return { data: null, error: { message: 'Unsupported query mode' } };
    }

    try {
      const result = await pool.query(sql, this.values);
      const rows = result.rows as any[];

      if (this.expectSingle) {
        if (rows.length === 1) {
          return { data: rows[0], error: null };
        }
        if (rows.length === 0) {
          return { data: null, error: { code: 'PGRST116', message: 'No rows found' } };
        }
        return {
          data: null,
          error: { code: 'PGRST117', message: 'Multiple rows found for single()' },
        };
      }

      if (this.expectMaybeSingle) {
        if (rows.length === 0) {
          return { data: null, error: null };
        }
        if (rows.length === 1) {
          return { data: rows[0], error: null };
        }
        return {
          data: null,
          error: { code: 'PGRST117', message: 'Multiple rows found for maybeSingle()' },
        };
      }

      if (this.mode === 'select' || this.returnRows) {
        return { data: rows as T, error: null };
      }

      return { data: null, error: null };
    } catch (error) {
      return { data: null, error: toDbError(error) };
    }
  }

  then<TResult1 = DbResult<T>, TResult2 = never>(
    onfulfilled?: ((value: DbResult<T>) => TResult1 | PromiseLike<TResult1>) | null,
    onrejected?: ((reason: unknown) => TResult2 | PromiseLike<TResult2>) | null,
  ): Promise<TResult1 | TResult2> {
    return this.execute().then(onfulfilled, onrejected);
  }
}

export const db = {
  from<T = any>(table: string): QueryBuilder<T> {
    return new QueryBuilder<T>(table);
  },
};