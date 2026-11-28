import assert from 'node:assert/strict'
import test from 'node:test'
import { computeCoinAdjustmentPreview } from '../../src/services/contracts/coinAdjustmentUtils.ts'

test('computeCoinAdjustmentPreview handles add, deduct, set, and guardrails', () => {
  const deductOk = computeCoinAdjustmentPreview('deduct', 30, 100)
  assert.equal(deductOk.valid, true)
  assert.equal(deductOk.delta, -30)
  assert.equal(deductOk.nextBalance, 70)

  const overDeduct = computeCoinAdjustmentPreview('deduct', 101, 100)
  assert.equal(overDeduct.valid, false)
  assert.match(overDeduct.error ?? '', /melebihi saldo/i)

  const setUp = computeCoinAdjustmentPreview('set', 150, 100)
  assert.equal(setUp.valid, true)
  assert.equal(setUp.delta, 50)
  assert.equal(setUp.nextBalance, 150)

  const setZero = computeCoinAdjustmentPreview('set', 0, 100)
  assert.equal(setZero.valid, true)
  assert.equal(setZero.delta, -100)
  assert.equal(setZero.nextBalance, 0)

  const setNoop = computeCoinAdjustmentPreview('set', 100, 100)
  assert.equal(setNoop.valid, false)

  const addOk = computeCoinAdjustmentPreview('add', 40, 100)
  assert.equal(addOk.valid, true)
  assert.equal(addOk.delta, 40)
  assert.equal(addOk.nextBalance, 140)
})
