{-# LANGUAGE CPP #-}
{-# LANGUAGE Rank2Types #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE LiberalTypeSynonyms #-}
{-# LANGUAGE MultiParamTypeClasses #-}
#ifdef TRUSTWORTHY
{-# LANGUAGE Trustworthy #-}
#endif
-------------------------------------------------------------------------------
-- |
-- Module      :  Data.Vector.Lens
-- Copyright   :  (C) 2012 Edward Kmett
-- License     :  BSD-style (see the file LICENSE)
-- Maintainer  :  Edward Kmett <ekmett@gmail.com>
-- Stability   :  provisional
-- Portability :  non-portable
--
-- This module provides lenses and traversals for working with generic vectors.
-------------------------------------------------------------------------------
module Data.Vector.Lens
  ( toVectorOf
  -- * Isomorphisms
  , vector
  , reversed
  , forced
  -- * Lenses
  , _head
  , _tail
  , _last
  , _init
  , sliced
  -- * Traversal of individual indices
  , ordinal
  , ordinals
  ) where

import Control.Lens
import Data.Vector as Vector hiding (zip, filter, indexed)
import Prelude hiding ((++), length, head, tail, init, last, map, reverse)
import Data.List (nub)
import Data.Monoid

-- | A lens reading and writing to the 'head' of a /non-empty/ 'Vector'
--
-- Attempting to read or write to the 'head' of an /empty/ 'Vector' will result in an 'error'.
--
-- >>> Vector.fromList [1,2,3]^._head
-- 1
_head :: SimpleLens (Vector a) a
_head f v = f (head v) <&> \a -> v // [(0,a)]
{-# INLINE _head #-}

-- | A 'Lens' reading and writing to the 'last' element of a /non-empty/ 'Vector'
--
-- Attempting to read or write to the 'last' element of an /empty/ 'Vector' will result in an 'error'.
--
-- >>> Vector.fromList [1,2]^._last
-- 2
_last :: SimpleLens (Vector a) a
_last f v = f (last v) <&> \a -> v // [(length v - 1, a)]
{-# INLINE _last #-}

-- | A lens reading and writing to the 'tail' of a /non-empty/ 'Vector'
--
-- Attempting to read or write to the 'tail' of an /empty/ 'Vector' will result in an 'error'.
--
-- >>> _tail .~ Vector.fromList [3,4,5] $ Vector.fromList [1,2]
-- fromList [1,3,4,5]
_tail :: SimpleLens (Vector a) (Vector a)
_tail f v = f (tail v) <&> cons (head v)
{-# INLINE _tail #-}

-- | A 'Lens' reading and replacing all but the a 'last' element of a /non-empty/ 'Vector'
--
-- Attempting to read or write to all but the 'last' element of an /empty/ 'Vector' will result in an 'error'.
--
-- >>> Vector.fromList [1,2,3,4]^._init
-- fromList [1,2,3]
_init :: SimpleLens (Vector a) (Vector a)
_init f v = f (init v) <&> (`snoc` last v)
{-# INLINE _init #-}

-- | @sliced i n@ provides a lens that edits the @n@ elements starting at index @i@ from a lens.
--
-- This is only a valid lens if you do not change the length of the resulting 'Vector'.
--
-- Attempting to return a longer or shorter vector will result in violations of the 'Lens' laws.
sliced :: Int -- ^ @i@ starting index
       -> Int -- ^ @n@ length
       -> SimpleLens (Vector a) (Vector a)
sliced i n f v = f (slice i n v) <&> \ v0 -> v // zip [i..i+n-1] (toList v0)
{-# INLINE sliced #-}

-- | Similar to 'toListOf', but returning a 'Vector'.
toVectorOf :: Getting (Endo [a]) s t a b -> s -> Vector a
toVectorOf l s = fromList (toListOf l s)
{-# INLINE toVectorOf #-}

-- | Convert a list to a 'Vector' (or back)
vector :: Iso [a] [b] (Vector a) (Vector b)
vector = iso fromList toList
{-# INLINE vector #-}

-- | Convert a 'Vector' to a version with all the elements in the reverse order
reversed :: Iso (Vector a) (Vector b) (Vector a) (Vector b)
reversed = iso reverse reverse
{-# INLINE reversed #-}

-- | Convert a 'Vector' to a version that doesn't retain any extra memory.
forced :: Iso (Vector a) (Vector b) (Vector a) (Vector b)
forced = iso force force
{-# INLINE forced #-}

-- | This is a more efficient version of 'element' that works for any 'Vector'.
--
-- @ordinal n@ is only a valid 'Lens' into a 'Vector' with 'length' at least @n + 1@.
ordinal :: Int -> SimpleIndexedLens Int (Vector a) a
ordinal i = indexed $ \ f v -> f i (v ! i) <&> \ a -> v // [(i, a)]
{-# INLINE ordinal #-}

-- | This 'Traversal' will ignore any duplicates in the supplied list of indices.
--
-- >>> toListOf (ordinals [1,3,2,5,9,10]) $ Vector.fromList [2,4..40]
-- [4,8,6,12,20,22]
ordinals :: [Int] -> SimpleIndexedTraversal Int (Vector a) a
ordinals is = indexed $ \ f v -> let
     l = length v
     is' = nub $ filter (<l) is
  in fmap ((v //) . zip is') . traverse (uncurry f) . zip is $ fmap (v !) is'
{-# INLINE ordinals #-}
